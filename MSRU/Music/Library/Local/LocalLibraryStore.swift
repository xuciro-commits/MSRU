import Foundation
import Observation
import AppFoundation

@MainActor
@Observable
final class LocalLibraryStore {
    private(set) var tracks: [LocalTrack] = []
    private(set) var revision: UInt64 = 0
    private(set) var querySnapshot: LibraryQuerySnapshot = LibraryQuerySnapshot()
    private var cachedAlbums: [AlbumPresentationModel] = []
    private var cachedArtists: [ArtistPresentationModel] = []
    private(set) var isImporting = false
    private(set) var errorMessage: String?
    private var didLoad = false
    private var pendingOperation: Task<Void, Never>?
    private var operationID: UUID?
    private var pendingImports = 0
    private let repository: any LocalLibraryRepository
    private let db: AppDatabase
    private let queryEngine: LibraryQueryEngine

    var albums: [AlbumPresentationModel] {
        if !cachedAlbums.isEmpty {
            return cachedAlbums
        }
        return querySnapshot.albumSummaries
    }

    var artists: [ArtistPresentationModel] {
        if !cachedArtists.isEmpty {
            return cachedArtists
        }
        return querySnapshot.artistSummaries
    }

    var positionLookup: [String: Int] {
        querySnapshot.positionLookup
    }

    var isLoading: Bool {
        !didLoad
    }

    var isLoaded: Bool {
        didLoad
    }

    private func updateCachedPresentations() {
        self.cachedAlbums = LibraryPresentationAggregator.buildAlbums(from: tracks)
        self.cachedArtists = LibraryPresentationAggregator.buildArtists(from: tracks)
        self.revision &+= 1
    }

    private func refreshQuerySnapshot() async {
        let snapshot = await queryEngine.querySnapshot()
        self.querySnapshot = snapshot
    }

    convenience init() {
        self.init(repository: FileLocalLibraryRepository(), db: AppDatabase.shared)
    }

    init(repository: any LocalLibraryRepository, db: AppDatabase = AppDatabase.shared) {
        self.repository = repository
        self.db = db
        self.queryEngine = LibraryQueryEngine(db: db)
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
            updateCachedPresentations()

            printArtworkMemoryDiagnostics()

            didLoad = true
            errorMessage = nil

            await syncTracksToDatabase(tracks)
            await refreshQuerySnapshot()
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
            self.updateCachedPresentations()
            await self.syncTracksToDatabase(newTracks)
            await self.refreshQuerySnapshot()
            await LocalLibraryIndexingService.shared.enqueue(newTracks)
        }
    }

    private func syncTracksToDatabase(_ newTracks: [LocalTrack]) async {
        let identityRepo = IdentityRepository(db: self.db)
        let assetRepo = AssetRepository(db: self.db)
        let sourceRepo = SourceRepository(db: self.db)
        let sourceID = SourceID("src_local_default")

        let defaultSource = Source(
            id: sourceID,
            sourceType: .localFolder,
            uri: "local://default",
            displayName: "Local Media Library",
            capabilities: .localFolderDefault,
            isEnabled: true
        )
        try? await sourceRepo.insertOrUpdate(defaultSource)

        var artists: [(id: ArtistID, name: String)] = []
        var recordings: [(id: RecordingID, title: String, duration: Double?)] = []
        var releaseGroups: [(id: ReleaseGroupID, title: String)] = []
        var releases: [(id: ReleaseID, releaseGroupID: ReleaseGroupID?, title: String, year: Int?, artworkAssetID: String?)] = []
        var releaseTracks: [(id: ReleaseTrackID, releaseID: ReleaseID, trackNumber: Int, title: String, duration: Double?, recordingID: RecordingID)] = []
        var artistCredits: [(artistID: ArtistID, entityType: String, entityID: String)] = []
        var assets: [PersistedAssetRecord] = []

        for track in newTracks {
            let relTitle = track.album ?? "Unknown Album"
            let recID = DeterministicID.recording(title: track.title, artist: track.artist)
            let artID = DeterministicID.artist(name: track.artist)
            let rgID = DeterministicID.releaseGroup(artist: track.artist, title: relTitle)
            let relID = DeterministicID.release(artist: track.artist, title: relTitle)
            let trkID = DeterministicID.releaseTrack(releaseID: relID, medium: 1, track: track.trackNumber ?? 1)
            let astID = DeterministicID.asset(sourceID: sourceID, relativePath: track.fileURL.standardizedFileURL.path)

            artists.append((id: artID, name: track.artist))
            recordings.append((id: recID, title: track.title, duration: track.duration))
            releaseGroups.append((id: rgID, title: relTitle))
            releases.append((id: relID, releaseGroupID: rgID, title: relTitle, year: track.year, artworkAssetID: track.artworkReference))
            releaseTracks.append((id: trkID, releaseID: relID, trackNumber: track.trackNumber ?? 1, title: track.title, duration: track.duration, recordingID: recID))
            artistCredits.append((artistID: artID, entityType: "recording", entityID: recID.rawValue))
            artistCredits.append((artistID: artID, entityType: "release", entityID: relID.rawValue))

            assets.append(PersistedAssetRecord(
                id: astID,
                sourceID: sourceID,
                relativePath: track.fileURL.standardizedFileURL.path,
                fileSize: 0,
                mtime: Date().timeIntervalSince1970,
                format: track.fileURL.pathExtension.uppercased(),
                duration: track.duration,
                recordingID: recID
            ))
        }

        try? await identityRepo.batchUpsertEntities(
            artists: artists,
            recordings: recordings,
            releaseGroups: releaseGroups,
            releases: releases,
            releaseTracks: releaseTracks,
            artistCredits: artistCredits
        )
        try? await assetRepo.batchUpsert(assets)
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
            self.updateCachedPresentations()
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
            updateCachedPresentations()
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
