import Foundation
import Observation
import AppFoundation

@MainActor
@Observable
final class LocalLibraryStore {
    private(set) var tracks: [LocalTrack] = []
    private(set) var isImporting = false
    private(set) var errorMessage: String?
    private var didLoad = false
    private var pendingOperation: Task<Void, Never>?
    private var operationID: UUID?
    private var pendingImports = 0
    private let repository: any LocalLibraryRepository

    convenience init() {
        self.init(repository: FileLocalLibraryRepository())
    }

    init(repository: any LocalLibraryRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        await serialized {
            guard !self.didLoad else { return }
            await self.reloadNow()
        }
    }

    func reload() async {
        await serialized { await self.reloadNow() }
    }

    private func reloadNow() async {
        do {
            tracks = try await repository.loadTracks()
            didLoad = true
            errorMessage = nil
        } catch {
            didLoad = false
            errorMessage = error.localizedDescription
        }
    }

    func addTracks(_ newTracks: [LocalTrack]) async {
        guard !newTracks.isEmpty else { return }
        await serialized {
            for track in newTracks {
                try? await self.repository.saveTrackInPlace(track)
                if let index = self.tracks.firstIndex(where: { $0.id == track.id || $0.fileURL.standardizedFileURL == track.fileURL.standardizedFileURL }) {
                    self.tracks[index] = track
                } else {
                    self.tracks.append(track)
                }
            }
            self.tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            self.registerTracksInMemory(newTracks)
        }
    }

    func deleteTracks(withIDs ids: Set<String>, deletePhysical: Bool = false) async {
        guard !ids.isEmpty else { return }
        await serialized {
            let deletedTracks = self.tracks.filter {
                ids.contains($0.id) ||
                ids.contains($0.fileURL.standardizedFileURL.path) ||
                ids.contains($0.fileURL.path)
            }
            self.tracks.removeAll {
                ids.contains($0.id) ||
                ids.contains($0.fileURL.standardizedFileURL.path) ||
                ids.contains($0.fileURL.path)
            }
            try? await self.repository.deleteTracks(withIDs: ids, deletePhysicalFiles: deletePhysical)
            self.deregisterTracks(deletedTracks)
        }
    }

    func deleteAlbum(title: String, artist: String, deletePhysical: Bool = false) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let trackIDsToDelete = Set(tracks.filter { track in
            let matchTitle = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanTitle)
            let matchArtist = cleanArtist.isEmpty || (track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanArtist)
            return matchTitle && matchArtist
        }.map(\.id))

        await deleteTracks(withIDs: trackIDsToDelete, deletePhysical: deletePhysical)
    }

    func deleteArtist(name: String, deletePhysical: Bool = false) async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let trackIDsToDelete = Set(tracks.filter { track in
            track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName
        }.map(\.id))

        await deleteTracks(withIDs: trackIDsToDelete, deletePhysical: deletePhysical)
    }

    private func deregisterTracks(_ tracks: [LocalTrack]) {
        // Clear in-memory references
    }

    func importFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        pendingImports += 1
        isImporting = true
        defer {
            pendingImports -= 1
            isImporting = pendingImports > 0
        }
        await serialized {
            var audioURLs: [URL] = []
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        while let fileURL = enumerator.nextObject() as? URL {
                            if LocalAudioFormatSupport.supports(fileURL) {
                                audioURLs.append(fileURL)
                            }
                        }
                    }
                } else if LocalAudioFormatSupport.supports(url) {
                    audioURLs.append(url)
                }
            }
            await self.importNow(audioURLs)
        }
    }

    private func importNow(_ urls: [URL]) async {
        errorMessage = nil
        var newlyImported: [LocalTrack] = []
        do {
            for url in urls {
                guard let track = try await repository.importTrack(from: url) else { continue }
                if let index = tracks.firstIndex(where: { $0.id == track.id || $0.fileURL.standardizedFileURL == track.fileURL.standardizedFileURL }) {
                    tracks[index] = track
                } else {
                    tracks.append(track)
                }
                newlyImported.append(track)
            }
            tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            registerTracksInMemory(newlyImported)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func registerTracksInMemory(_ tracks: [LocalTrack]) {
        Task {
            let fingerprinter = AcoustIDFingerprintExtractor()
            for track in tracks {
                if let fp = try? await fingerprinter.generateFingerprint(for: track.fileURL) {
                    LocalFingerprintRegistry.shared.register(
                        fingerprint: fp.fingerprint,
                        duration: fp.duration,
                        title: track.title,
                        artist: track.artist,
                        album: track.album
                    )
                }
                PathHeuristicRuleStore.shared.learnFrom(
                    folderURL: track.fileURL.deletingLastPathComponent(),
                    artist: track.artist,
                    album: track.album
                )
            }
        }
    }

    // File scanning and importing share one ordered state commit path. An old scan
    // must not replace tracks imported while metadata loading was suspended.
    private func serialized(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = pendingOperation
        let id = UUID()
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        pendingOperation = task
        operationID = id
        await task.value
        if operationID == id {
            pendingOperation = nil
            operationID = nil
        }
    }
}
