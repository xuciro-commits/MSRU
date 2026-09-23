import Foundation
import Observation
import AppFoundation

@MainActor
@Observable
final class LocalLibraryStore {
    private(set) var tracks: [LocalTrack] = []
    private(set) var totalTrackCount = 0
    private(set) var isFullyLoaded = false
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
    private weak var libraryStore: LibraryStore?
    private weak var playlistStore: PlaylistStore?
    private weak var playbackController: PlaybackController?
    private var spotlightIndexer: SpotlightIndexingService?

    func attachSpotlightIndexer(_ indexer: SpotlightIndexingService) {
        spotlightIndexer = indexer
        if didLoad {
            indexer.schedule(repository: repository, albums: albums, artists: artists)
        }
    }

    func attachCascadeCollaborators(
        libraryStore: LibraryStore?,
        playlistStore: PlaylistStore?,
        playbackController: PlaybackController?
    ) {
        self.libraryStore = libraryStore
        self.playlistStore = playlistStore
        self.playbackController = playbackController
    }

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
        if isFullyLoaded {
            self.cachedAlbums = LibraryPresentationAggregator.buildAlbums(from: tracks)
            self.cachedArtists = LibraryPresentationAggregator.buildArtists(from: tracks)
        } else {
            self.cachedAlbums = []
            self.cachedArtists = []
        }
        self.revision &+= 1
    }

    private func refreshQuerySnapshot() async {
        let snapshot = await queryEngine.querySnapshot(includeOrderedIDs: false)
        self.querySnapshot = snapshot
        spotlightIndexer?.schedule(repository: repository, albums: albums, artists: artists)
    }

    convenience init() {
        self.init(repository: SQLiteLocalLibraryRepository(db: AppDatabase.shared), db: AppDatabase.shared)
    }

    init(repository: any LocalLibraryRepository, db: AppDatabase = AppDatabase.shared) {
        self.repository = repository
        self.db = db
        self.queryEngine = LibraryQueryEngine(db: db)
    }

    func makePager() -> LocalTrackPager {
        LocalTrackPager(repository: repository)
    }

    func fetchTracks(forReleaseIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await repository.fetchTracks(forReleaseIDs: ids)
    }

    func fetchTracks(forArtistIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await repository.fetchTracks(forArtistIDs: ids)
    }

    func fetchTracks(inFolder folder: URL) async throws -> [LocalTrack] {
        try await repository.fetchTracks(inFolder: folder)
    }

    func findTrack(id: String) async throws -> LocalTrack? {
        try await repository.fetchTracks(withIDs: [id]).first
    }

    func findUniqueTrack(title: String, artist: String?) async throws -> LocalTrack? {
        try await repository.findUniqueTrack(title: title, artist: artist)
    }

    func searchTracks(_ query: String, limit: Int = 10) async throws -> [LocalTrack] {
        try await repository.searchTracks(query, limit: limit)
    }

    func resolvePlaylistTracks(_ playlist: Playlist) async throws -> [LocalTrack] {
        if let rules = playlist.rules {
            var matches: [LocalTrack] = []
            var offset = 0
            let referenceDate = Date()
            let needsAddedAt = rules.rules.contains { $0.field == .addedAt }
                || rules.sortBy == .dateAddedDescending
            let narrowingQuery: String = {
                guard rules.matchMode == .all else { return "" }
                for rule in rules.rules {
                    guard [.title, .artist, .album].contains(rule.field),
                          [.contains, .equals, .startsWith, .endsWith].contains(rule.op),
                          case .string(let value) = rule.value else { continue }
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
                return ""
            }()
            while true {
                try Task.checkCancellation()
                let page = try await repository.fetchPage(
                    LocalTrackPageRequest(query: narrowingQuery, sort: .title,
                                          offset: offset, limit: 512)
                )
                matches.append(contentsOf: page.tracks.filter {
                    PlaylistRuleEngine.matches(
                        rules: rules,
                        track: TrackEvaluationContext($0, includeAddedAt: needsAddedAt),
                        referenceDate: referenceDate
                    )
                })
                offset += page.tracks.count
                if !page.hasMore { break }
                guard !page.tracks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            }
            return PlaylistRuleEngine.evaluate(
                rules: rules, tracks: matches, referenceDate: referenceDate
            )
        }

        let byID = try await repository.fetchTracks(withIDs: Set(playlist.trackIDs))
        var lookup: [String: LocalTrack] = [:]
        for track in byID {
            lookup[track.id] = track
            lookup[track.fileURL.path] = track
            lookup[track.fileURL.standardizedFileURL.path] = track
        }
        let legacyNames = playlist.trackIDs.filter { !$0.contains("/") && !$0.contains(":") }
        if !legacyNames.isEmpty {
            let all = try await repository.loadTracks()
            for track in all where legacyNames.contains(track.fileURL.lastPathComponent) {
                lookup[track.fileURL.lastPathComponent] = track
            }
        }
        return playlist.trackIDs.compactMap { lookup[$0] }
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
            if isFullyLoaded {
                tracks = try await repository.loadTracks()
                totalTrackCount = tracks.count
            } else {
                let page = try await repository.fetchPage(LocalTrackPageRequest(limit: 128))
                tracks = page.tracks
                totalTrackCount = page.totalCount
                isFullyLoaded = page.totalCount <= page.tracks.count
            }
            updateCachedPresentations()

            printArtworkMemoryDiagnostics()

            didLoad = true
            errorMessage = nil

            await refreshQuerySnapshot()
            if isFullyLoaded { triggerBackgroundArtworkBackfillIfNeeded() }
        } catch {
            didLoad = false
            errorMessage = error.localizedDescription
        }
    }

    /// Compatibility path for operations that still require every local track.
    /// Primary song views and startup use paged queries.
    func ensureAllTracksLoaded() async {
        await loadIfNeeded()
        await serialized {
            guard !self.isFullyLoaded else { return }
            do {
                let all = try await self.repository.loadTracks()
                self.tracks = all
                self.totalTrackCount = all.count
                self.isFullyLoaded = true
                self.errorMessage = nil
                self.updateCachedPresentations()
                await self.refreshQuerySnapshot()
                self.triggerBackgroundArtworkBackfillIfNeeded()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func reconcileDatabaseOrphans(validTracks: [LocalTrack]) async {
        var validPaths = Set<String>()
        var validFilenames = Set<String>()
        var validRecIDs = Set<RecordingID>()

        for t in validTracks {
            validPaths.insert(t.fileURL.standardizedFileURL.path)
            validPaths.insert(t.fileURL.path)
            validFilenames.insert(t.fileURL.lastPathComponent)
            validRecIDs.insert(DeterministicID.recording(title: t.title, artist: t.artist))
        }

        let identityRepo = IdentityRepository(db: self.db)
        try? await identityRepo.reconcileLocalAssets(
            validPaths: validPaths,
            validFilenames: validFilenames,
            validRecordingIDs: validRecIDs
        )
    }

    func addTracks(_ newTracks: [LocalTrack]) async throws {
        guard !newTracks.isEmpty else { return }
        try await serializedThrowing {
            try await self.repository.saveTracksInPlace(newTracks)
            if self.isFullyLoaded {
                var indices = Dictionary(uniqueKeysWithValues: self.tracks.enumerated().map { ($0.element.id, $0.offset) })
                for track in newTracks {
                    if let index = indices[track.id] {
                        self.tracks[index] = track
                    } else {
                        indices[track.id] = self.tracks.count
                        self.tracks.append(track)
                    }
                }
                self.tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                self.totalTrackCount = self.tracks.count
            } else {
                let page = try await self.repository.fetchPage(LocalTrackPageRequest(limit: 128))
                self.tracks = page.tracks
                self.totalTrackCount = page.totalCount
            }
            self.updateCachedPresentations()
            await self.refreshQuerySnapshot()
            await LocalLibraryIndexingService.shared.enqueue(newTracks)
            self.triggerBackgroundArtworkBackfillIfNeeded()
        }
    }

    @discardableResult
    func deleteTracks(withIDs ids: Set<String>, deletePhysical: Bool = false) async -> Bool {
        guard !ids.isEmpty else { return true }
        var succeeded = false
        await serialized {
            let deletedTracks: [LocalTrack]
            do {
                deletedTracks = try await self.repository.fetchTracks(withIDs: ids)
            } catch {
                self.errorMessage = error.localizedDescription
                return
            }
            guard !deletedTracks.isEmpty else {
                succeeded = true
                return
            }

            let deletedTrackIDs = Set(deletedTracks.map(\.id))
            let deletedURLs = Set(deletedTracks.map(\.fileURL))
            do {
                try await self.repository.deleteTracks(withIDs: deletedTrackIDs, deletePhysicalFiles: deletePhysical)
            } catch {
                self.errorMessage = error.localizedDescription
                return
            }

            self.tracks.removeAll { deletedTrackIDs.contains($0.id) }
            self.totalTrackCount = self.isFullyLoaded
                ? self.tracks.count
                : max(0, self.totalTrackCount - deletedTracks.count)

            // Cross-store cleanup follows a successful authoritative SQLite delete.
            await self.libraryStore?.purgeTracks(matchingIDs: deletedTrackIDs, localURLs: deletedURLs)
            await self.playlistStore?.purgeTracks(withIDs: deletedTrackIDs)
            self.playbackController?.purgeTracks(withIDs: deletedTrackIDs, localURLs: deletedURLs)

            self.updateCachedPresentations()
            self.deregisterTracks(deletedTracks)
            await self.refreshQuerySnapshot()
            succeeded = true
        }
        return succeeded
    }

    func deleteAlbum(title: String, artist: String, deletePhysical: Bool = false) async {
        await ensureAllTracksLoaded()
        guard isFullyLoaded else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let trackIDsToDelete = Set(tracks.filter { track in
            let matchTitle = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanTitle)
            let matchArtist = cleanArtist.isEmpty || (track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanArtist)
            return matchTitle && matchArtist
        }.map(\.id))

        if !trackIDsToDelete.isEmpty {
            guard await deleteTracks(withIDs: trackIDsToDelete, deletePhysical: deletePhysical) else { return }
        }

        // Always delete release in SQLite (even if in-memory tracks were already cleared)
        let releaseID = DeterministicID.release(artist: artist, title: title)
        let identityRepo = IdentityRepository(db: self.db)
        do {
            try await identityRepo.deleteRelease(id: releaseID, title: title, artist: artist)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await serialized {
            self.updateCachedPresentations()
            await self.refreshQuerySnapshot()
        }
    }

    func deleteArtist(name: String, deletePhysical: Bool = false) async {
        await ensureAllTracksLoaded()
        guard isFullyLoaded else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        var trackIDsToDelete = Set<String>()
        var tracksToUpdate = [LocalTrack]()

        for track in tracks {
            if ArtistCreditCleaner.containsArtist(cleanName, in: track.artist) {
                if ArtistCreditCleaner.isSoleArtist(cleanName, in: track.artist) {
                    // Sole artist: delete track
                    trackIDsToDelete.insert(track.id)
                } else if let cleanedArtist = ArtistCreditCleaner.removingArtist(cleanName, from: track.artist) {
                    // Collaboration: preserve track, update artist text
                    let updated = LocalTrack(
                        fileURL: track.fileURL,
                        title: track.title,
                        artist: cleanedArtist,
                        album: track.album,
                        duration: track.duration,
                        artworkReference: track.artworkReference,
                        trackNumber: track.trackNumber,
                        year: track.year
                    )
                    tracksToUpdate.append(updated)
                }
            }
        }

        // 1. Update collaboration tracks
        if !tracksToUpdate.isEmpty {
            do {
                try await repository.saveTracksInPlace(tracksToUpdate)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            await serialized {
                for updated in tracksToUpdate {
                    if let idx = self.tracks.firstIndex(where: { $0.id == updated.id }) {
                        self.tracks[idx] = updated
                    }
                }
            }
        }

        // 2. Delete sole-owned tracks (which cascades through SQLite and cross-stores)
        if !trackIDsToDelete.isEmpty {
            guard await deleteTracks(withIDs: trackIDsToDelete, deletePhysical: deletePhysical) else { return }
        }

        // 3. Always delete artist entity and credits in SQLite (even if in-memory tracks were already cleared)
        let artistID = DeterministicID.artist(name: cleanName)
        let identityRepo = IdentityRepository(db: self.db)
        do {
            try await identityRepo.deleteArtist(id: artistID, name: cleanName)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await serialized {
            self.updateCachedPresentations()
            await self.refreshQuerySnapshot()
        }
    }

    private func deregisterTracks(_ tracks: [LocalTrack]) {
        // Clear in-memory references
    }

    // MARK: - Re-identification & Artwork Resolution

    @discardableResult
    func reidentifyTrack(trackID: String) async -> Bool {
        await ensureAllTracksLoaded()
        guard isFullyLoaded else { return false }
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return false }
        let track = tracks[index]

        guard let result = await LocalArtworkExtractor.resolveRemoteArtwork(
            artist: track.artist,
            album: track.album,
            title: track.title
        ) else {
            return false
        }

        let artRef = LocalArtworkStorage.shared.storeArtwork(result.data)
        var newAlbum = track.album
        if let canonical = result.canonicalAlbum, !canonical.isEmpty {
            if newAlbum == nil || newAlbum?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                newAlbum = canonical
            }
        }

        let updatedTrack = LocalTrack(
            fileURL: track.fileURL,
            title: track.title,
            artist: track.artist,
            album: newAlbum,
            duration: track.duration,
            artworkReference: artRef,
            trackNumber: track.trackNumber,
            year: track.year
        )

        do {
            try await repository.saveTracksInPlace([updatedTrack])
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        tracks[index] = updatedTrack
        updateCachedPresentations()
        await refreshQuerySnapshot()
        return true
    }

    @discardableResult
    func reidentifyAlbum(albumTitle: String, artist: String) async -> Bool {
        await ensureAllTracksLoaded()
        guard isFullyLoaded else { return false }
        let cleanArt = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanAlb = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let matchingIndices = tracks.indices.filter { idx in
            let t = tracks[idx]
            let tArt = t.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tAlb = (t.album ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return tArt == cleanArt && (tAlb == cleanAlb || cleanAlb.isEmpty)
        }
        guard !matchingIndices.isEmpty else { return false }

        guard let result = await LocalArtworkExtractor.resolveRemoteArtwork(
            artist: artist,
            album: albumTitle,
            title: tracks[matchingIndices.first!].title
        ) else {
            return false
        }

        let artRef = LocalArtworkStorage.shared.storeArtwork(result.data)
        var modifiedTracks: [LocalTrack] = []

        for idx in matchingIndices {
            let t = tracks[idx]
            var newAlbum = t.album
            if let canonical = result.canonicalAlbum, !canonical.isEmpty {
                if newAlbum == nil || newAlbum?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanArt {
                    newAlbum = canonical
                }
            }
            let updated = LocalTrack(
                fileURL: t.fileURL,
                title: t.title,
                artist: t.artist,
                album: newAlbum,
                duration: t.duration,
                artworkReference: artRef,
                trackNumber: t.trackNumber,
                year: t.year
            )
            modifiedTracks.append(updated)
        }

        do {
            try await repository.saveTracksInPlace(modifiedTracks)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        for updated in modifiedTracks {
            if let index = tracks.firstIndex(where: { $0.id == updated.id }) {
                tracks[index] = updated
            }
        }
        updateCachedPresentations()
        await refreshQuerySnapshot()
        return true
    }

    @discardableResult
    func remediateLibraryMetadataAndArtwork(progress: ((Int, Int) -> Void)? = nil) async -> (repairedCount: Int, artworkAddedCount: Int) {
        await ensureAllTracksLoaded()
        guard isFullyLoaded else { return (0, 0) }
        var repaired = 0
        var artworkAdded = 0
        var updatedTracks: [LocalTrack] = []

        let total = tracks.count
        for (i, currentTrack) in tracks.enumerated() {
            progress?(i + 1, total)

            var modified = false
            var newTitle = currentTrack.title
            var newArtist = currentTrack.artist
            var newAlbum = currentTrack.album
            var newYear = currentTrack.year
            var newTrackNo = currentTrack.trackNumber
            var newArtRef = currentTrack.artworkReference

            // 1. Re-read tags from file if accessible
            if FileManager.default.fileExists(atPath: currentTrack.fileURL.path) {
                if let fresh = try? await FileLocalLibraryRepository.readTrack(from: currentTrack.fileURL) {
                    if fresh.title != newTitle {
                        newTitle = fresh.title
                        modified = true
                    }
                    if fresh.artist != newArtist {
                        newArtist = fresh.artist
                        modified = true
                    }
                    if let freshAlbum = fresh.album, freshAlbum != newAlbum {
                        newAlbum = freshAlbum
                        modified = true
                    }
                    if let freshYear = fresh.year, freshYear != newYear {
                        newYear = freshYear
                        modified = true
                    }
                    if let freshNo = fresh.trackNumber, freshNo != newTrackNo {
                        newTrackNo = freshNo
                        modified = true
                    }
                    if let freshArt = fresh.artworkReference, newArtRef == nil {
                        newArtRef = freshArt
                        artworkAdded += 1
                        modified = true
                    }
                }
            }

            // 2. Disambiguate album == artist
            if let alb = newAlbum, alb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == newArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                newAlbum = nil
                modified = true
            }

            // 3. Fallback to companion artwork file in same folder
            if newArtRef == nil {
                let folder = currentTrack.fileURL.deletingLastPathComponent()
                if let folderArtData = LocalArtworkExtractor.extractFromDirectory(folderURL: folder) {
                    let artRef = LocalArtworkStorage.shared.storeArtwork(folderArtData)
                    newArtRef = artRef
                    artworkAdded += 1
                    modified = true
                }
            }

            // 4. Remote artwork resolution fallback (MusicBrainz Pinyin + Apple Music)
            if newArtRef == nil {
                if let remoteResult = await LocalArtworkExtractor.resolveRemoteArtwork(
                    artist: newArtist,
                    album: newAlbum,
                    title: newTitle
                ) {
                    let artRef = LocalArtworkStorage.shared.storeArtwork(remoteResult.data)
                    newArtRef = artRef
                    if let canonical = remoteResult.canonicalAlbum, !canonical.isEmpty,
                       newAlbum == nil || newAlbum?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == newArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                        newAlbum = canonical
                    }
                    artworkAdded += 1
                    modified = true
                }
            }

            if modified {
                repaired += 1
                let updated = LocalTrack(
                    fileURL: currentTrack.fileURL,
                    title: newTitle,
                    artist: newArtist,
                    album: newAlbum,
                    duration: currentTrack.duration,
                    artworkReference: newArtRef,
                    trackNumber: newTrackNo,
                    year: newYear
                )
                updatedTracks.append(updated)
            }
        }

        if !updatedTracks.isEmpty {
            do {
                try await repository.saveTracksInPlace(updatedTracks)
            } catch {
                errorMessage = error.localizedDescription
                return (0, 0)
            }
            for updated in updatedTracks {
                if let index = tracks.firstIndex(where: { $0.id == updated.id }) {
                    tracks[index] = updated
                }
            }
            updateCachedPresentations()
            await refreshQuerySnapshot()
        }

        return (repaired, artworkAdded)
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
            if isFullyLoaded {
                var indices = Dictionary(uniqueKeysWithValues: tracks.enumerated().map { ($0.element.id, $0.offset) })
                for track in newlyImported {
                    if let index = indices[track.id] {
                        tracks[index] = track
                    } else {
                        indices[track.id] = tracks.count
                        tracks.append(track)
                    }
                }
                tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                totalTrackCount = tracks.count
            } else {
                let page = try await repository.fetchPage(LocalTrackPageRequest(limit: 128))
                tracks = page.tracks
                totalTrackCount = page.totalCount
            }
            updateCachedPresentations()
            await refreshQuerySnapshot()
            await LocalLibraryIndexingService.shared.enqueue(newlyImported)
            triggerBackgroundArtworkBackfillIfNeeded()
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
        tracks total: \(totalTrackCount)
        tracks resident: \(tracks.count)
        tracks with artwork reference: \(referenceCount)
        LocalTrack resident artwork bytes: 0 (Decoupled on-demand storage)
        ==============================
        """)
    }

    private var backfillTask: Task<Void, Never>?

    /// Triggers an asynchronous, non-blocking background task to resolve artwork for albums missing covers.
    func triggerBackgroundArtworkBackfillIfNeeded() {
        guard isFullyLoaded else { return }
        guard backfillTask == nil else { return }

        backfillTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            // 1. Identify all albums missing artwork
            let tracksSnapshot = self.tracks
            var missingAlbums: [String: (artist: String, album: String?, sampleTitle: String, trackIndices: [Int])] = [:]

            for (idx, track) in tracksSnapshot.enumerated() {
                if track.artworkReference == nil {
                    let albumKey = track.album ?? "Unknown Album (\(track.artist))"
                    let primaryArtist = track.artist.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? track.artist
                    let key = "\(primaryArtist) — \(albumKey)"

                    if missingAlbums[key] == nil {
                        missingAlbums[key] = (primaryArtist, track.album, track.title, [idx])
                    } else {
                        missingAlbums[key]?.trackIndices.append(idx)
                    }
                }
            }

            guard !missingAlbums.isEmpty else {
                self.backfillTask = nil
                return
            }

            print("[ArtworkBackfill] Starting background artwork backfill for \(missingAlbums.count) albums...")

            for (_, group) in missingAlbums {
                if Task.isCancelled { break }

                // Rate limiting pause
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { break }

                guard let resolved = await LocalArtworkExtractor.resolveRemoteArtwork(
                    artist: group.artist,
                    album: group.album,
                    title: group.sampleTitle
                ) else {
                    continue
                }

                let artRef = LocalArtworkStorage.shared.storeArtwork(resolved.data)
                var updatedBatch: [LocalTrack] = []

                for idx in group.trackIndices {
                    guard idx < self.tracks.count else { continue }
                    let oldTrack = self.tracks[idx]
                    var updatedAlbum = oldTrack.album
                    if let canonical = resolved.canonicalAlbum, !canonical.isEmpty,
                       updatedAlbum == nil || updatedAlbum?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == group.artist.lowercased() {
                        updatedAlbum = canonical
                    }

                    let updated = LocalTrack(
                        fileURL: oldTrack.fileURL,
                        title: oldTrack.title,
                        artist: oldTrack.artist,
                        album: updatedAlbum,
                        duration: oldTrack.duration,
                        artworkReference: artRef,
                        trackNumber: oldTrack.trackNumber,
                        year: oldTrack.year
                    )
                    updatedBatch.append(updated)
                }

                if !updatedBatch.isEmpty {
                    do {
                        try await self.repository.saveTracksInPlace(updatedBatch)
                    } catch {
                        self.errorMessage = error.localizedDescription
                        continue
                    }
                    for updated in updatedBatch {
                        if let index = self.tracks.firstIndex(where: { $0.id == updated.id }) {
                            self.tracks[index] = updated
                        }
                    }
                    self.updateCachedPresentations()
                    await self.refreshQuerySnapshot()
                    print("[ArtworkBackfill] Backfilled artwork for album: [\(group.album ?? "Unknown")] (\(updatedBatch.count) tracks)")
                }
            }

            self.backfillTask = nil
            print("[ArtworkBackfill] Background backfill completed.")
        }
    }
}
