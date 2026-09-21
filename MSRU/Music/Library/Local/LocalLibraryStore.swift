import Foundation
import Observation
import AppFoundation

@MainActor
@Observable
final class LocalLibraryStore {
    private(set) var tracks: [LocalTrack] = []
    private(set) var querySnapshot: LibraryQuerySnapshot = LibraryQuerySnapshot()
    private(set) var isImporting = false
    private(set) var errorMessage: String?
    private var didLoad = false
    private var pendingOperation: Task<Void, Never>?
    private var operationID: UUID?
    private var pendingImports = 0
    private let repository: any LocalLibraryRepository

    var albums: [AlbumPresentationModel] {
        querySnapshot.albumSummaries
    }

    var artists: [ArtistPresentationModel] {
        querySnapshot.artistSummaries
    }

    var positionLookup: [String: Int] {
        querySnapshot.positionLookup
    }

    private func refreshQuerySnapshot() async {
        _ = await LibraryQueryEngine.shared.setSourceLocalTracks(tracks)
        let snapshot = await LibraryQueryEngine.shared.querySnapshot()
        self.querySnapshot = snapshot
    }

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

            printArtworkMemoryDiagnostics()

            await refreshQuerySnapshot()

            didLoad = true
            errorMessage = nil
        } catch {
            didLoad = false
            errorMessage = error.localizedDescription
        }
    }

    func addTracks(_ newTracks: [LocalTrack]) async throws {
        guard !newTracks.isEmpty else { return }
        try await serializedThrowing {
            try await self.repository.saveTracksInPlace(newTracks)
            for track in newTracks {
                if let index = self.tracks.firstIndex(where: { $0.id == track.id || $0.fileURL.standardizedFileURL == track.fileURL.standardizedFileURL }) {
                    self.tracks[index] = track
                } else {
                    self.tracks.append(track)
                }
            }
            self.tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            await self.refreshQuerySnapshot()
            await LocalLibraryIndexingService.shared.enqueue(newTracks)
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
            await self.refreshQuerySnapshot()
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
        do {
            let newlyImported = try await repository.importTracks(from: urls)
            for track in newlyImported {
                if let index = tracks.firstIndex(where: { $0.id == track.id || $0.fileURL.standardizedFileURL == track.fileURL.standardizedFileURL }) {
                    tracks[index] = track
                } else {
                    tracks.append(track)
                }
            }
            tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            await refreshQuerySnapshot()
            await LocalLibraryIndexingService.shared.enqueue(newlyImported)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // File scanning and importing share one ordered state commit path. An old scan
    // must not replace tracks imported while metadata loading was suspended.
    private func serializedThrowing(_ operation: @escaping @MainActor () async throws -> Void) async throws {
        let previous = pendingOperation
        let id = UUID()
        let task = Task { @MainActor () throws -> Void in
            _ = await previous?.result
            try await operation()
        }
        pendingOperation = Task { _ = try? await task.value }
        operationID = id
        let result = await task.result
        if operationID == id {
            pendingOperation = nil
            operationID = nil
        }
        switch result {
        case .success:
            break
        case .failure(let error):
            self.errorMessage = error.localizedDescription
            throw error
        }
    }

    private func serialized(_ operation: @escaping @MainActor () async -> Void) async {
        try? await serializedThrowing {
            await operation()
        }
    }
    
    private func printArtworkMemoryDiagnostics() {
        let referenceCount = tracks.filter { $0.artworkReference != nil }.count

        print("""
        ==============================
        MSRU Artwork Memory Diagnostics
        ==============================
        tracks total: \(tracks.count)
        tracks with artwork reference: \(referenceCount)
        LocalTrack resident artwork bytes: 0 (Decoupled on-demand storage)
        ==============================
        """)
    }
}
