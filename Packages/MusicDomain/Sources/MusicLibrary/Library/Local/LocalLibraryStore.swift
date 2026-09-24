import Foundation
import Observation
import AppFoundation
import MusicDomain

/// Playback-side collaborator told when local tracks leave the library, so
/// queued items can be purged without the library depending on playback.
public protocol LocalTrackRemovalObserver: AnyObject {
    func purgeTracks(withIDs ids: Set<String>, localURLs: Set<URL>)
}

@MainActor
@Observable
public final class LocalLibraryStore {
    public private(set) var tracks: [LocalTrack] = []
    public private(set) var totalTrackCount = 0
    public private(set) var isFullyLoaded = false
    public private(set) var revision: UInt64 = 0
    public private(set) var isImporting = false
    public private(set) var errorMessage: String?
    private var didLoad = false
    private var pendingOperation: Task<Void, Never>?
    private var operationID: UUID?
    private var pendingImports = 0
    private let repository: any LocalLibraryRepository
    private let db: AppDatabase
    private let summaryRepository: LocalSummaryRepository
    private weak var playlistStore: PlaylistStore?
    private weak var playbackController: (any LocalTrackRemovalObserver)?
    private var spotlightIndexer: SpotlightIndexingService?

    public func attachSpotlightIndexer(_ indexer: SpotlightIndexingService) {
        spotlightIndexer = indexer
        if didLoad {
            indexer.schedule(repository: repository, summaries: summaryRepository)
        }
    }

    public func attachCascadeCollaborators(
        playlistStore: PlaylistStore?,
        playbackController: (any LocalTrackRemovalObserver)?
    ) {
        self.playlistStore = playlistStore
        self.playbackController = playbackController
    }

    public var isLoading: Bool {
        !didLoad
    }

    public var isLoaded: Bool {
        didLoad
    }

    private func updateCachedPresentations() {
        self.revision &+= 1
    }

    private func scheduleSpotlightRefresh() {
        spotlightIndexer?.schedule(repository: repository, summaries: summaryRepository)
    }

    public convenience init() {
        self.init(repository: SQLiteLocalLibraryRepository(db: AppDatabase.shared), db: AppDatabase.shared)
    }

    public init(repository: any LocalLibraryRepository, db: AppDatabase = AppDatabase.shared) {
        self.repository = repository
        self.db = db
        self.summaryRepository = LocalSummaryRepository(db: db)
    }

    public func makePager() -> LocalTrackPager {
        LocalTrackPager(repository: repository)
    }

    public func makeAlbumPager() -> LocalAlbumPager { LocalAlbumPager(repository: summaryRepository) }
    public func makeArtistPager() -> LocalArtistPager { LocalArtistPager(repository: summaryRepository) }
    public func findAlbum(id: String) async throws -> AlbumPresentationModel? {
        try await summaryRepository.album(id: id)
    }
    public func findArtist(id: String) async throws -> ArtistPresentationModel? {
        try await summaryRepository.artist(id: id)
    }

    public func fetchTracks(forReleaseIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await repository.fetchTracks(forReleaseIDs: ids)
    }

    public func fetchTracks(forArtistIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await repository.fetchTracks(forArtistIDs: ids)
    }

    public func fetchTracks(inFolder folder: URL) async throws -> [LocalTrack] {
        try await repository.fetchTracks(inFolder: folder)
    }

    public func findTrack(id: String) async throws -> LocalTrack? {
        try await repository.fetchTracks(withIDs: [id]).first
    }

    /// Records a user correction of a track's displayed metadata; `nil` restores the scanned value.
    /// `expectedRevision` is the revision shown with the corrections; returns the new one.
    @discardableResult
    public func correct(_ track: LocalTrack, field: MetadataCorrections.Field, value: String?, expectedRevision: UInt32?) async throws -> UInt32 {
        let revision = try await repository.correct(track, field: field, value: value, expectedRevision: expectedRevision)
        updateCachedPresentations()
        return revision
    }

    public func corrections(of track: LocalTrack) async throws -> MetadataCorrections.History {
        try await repository.corrections(of: track)
    }

    public func findUniqueTrack(title: String, artist: String?) async throws -> LocalTrack? {
        try await repository.findUniqueTrack(title: title, artist: artist)
    }

    public func searchTracks(_ query: String, limit: Int = 10) async throws -> [LocalTrack] {
        try await repository.searchTracks(query, limit: limit)
    }

    public func fingerprintCleanupReferences() async throws -> (keys: Set<String>, paths: Set<String>) {
        var keys = Set<String>()
        var paths = Set<String>()
        var afterPath: String?
        while true {
            try Task.checkCancellation()
            let page = try await repository.fetchMaintenancePage(afterPath: afterPath, limit: 512)
            guard !page.tracks.isEmpty else { break }
            for track in page.tracks {
                keys.insert("\(track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\(track.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())")
                paths.insert(track.fileURL.resolvingSymlinksInPath().standardizedFileURL.path)
            }
            afterPath = page.nextPath
        }
        return (keys, paths)
    }

    public func resolvePlaylistTracks(_ playlist: Playlist) async throws -> [LocalTrack] {
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
            let matches = try await repository.fetchTracks(withFilenames: Set(legacyNames))
            for track in matches {
                lookup[track.fileURL.lastPathComponent] = track
            }
        }
        return playlist.trackIDs.compactMap { lookup[$0] }
    }

    public func loadIfNeeded() async {
        await serialized {
            guard !self.didLoad else { return }
            await self.reloadNow()
        }
    }

    public func reload() async {
        await serialized { await self.reloadNow() }
    }

    private func reloadNow() async {
        do {
            let page = try await repository.fetchPage(LocalTrackPageRequest(limit: 128))
            tracks = page.tracks
            totalTrackCount = page.totalCount
            isFullyLoaded = page.totalCount <= page.tracks.count
            updateCachedPresentations()

            printArtworkMemoryDiagnostics()

            didLoad = true
            errorMessage = nil

            scheduleSpotlightRefresh()
            if isFullyLoaded { triggerBackgroundArtworkBackfillIfNeeded() }
        } catch {
            didLoad = false
            errorMessage = error.localizedDescription
        }
    }

    public func addTracks(_ newTracks: [LocalTrack]) async throws {
        guard !newTracks.isEmpty else { return }
        try await serializedThrowing {
            try await self.repository.saveTracksInPlace(newTracks)
            let page = try await self.repository.fetchPage(LocalTrackPageRequest(limit: 128))
            self.tracks = page.tracks
            self.totalTrackCount = page.totalCount
            self.isFullyLoaded = page.totalCount <= page.tracks.count
            self.updateCachedPresentations()
            self.scheduleSpotlightRefresh()
            await LocalLibraryIndexingService.shared.enqueue(newTracks)
            self.triggerBackgroundArtworkBackfillIfNeeded()
        }
    }

    @discardableResult
    public func deleteTracks(withIDs ids: Set<String>, deletePhysical: Bool = false) async -> Bool {
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

            // SQLite removes persisted references in the same transaction as assets.
            // These store calls synchronize any already-loaded in-memory collections.
            let playlistsSynchronized = await self.playlistStore?.purgeTracks(withIDs: deletedTrackIDs) ?? true
            if !playlistsSynchronized {
                await self.playlistStore?.load()
                self.errorMessage = "Local files were removed, but saved collections could not refresh. Reopen the library to retry."
            }
            self.playbackController?.purgeTracks(withIDs: deletedTrackIDs, localURLs: deletedURLs)

            self.updateCachedPresentations()
            self.deregisterTracks(deletedTracks)
            self.scheduleSpotlightRefresh()
            succeeded = true
        }
        return succeeded
    }

    public func moveTrack(from oldURL: URL, to newURL: URL) async throws {
        try await serializedThrowing {
            try await self.repository.moveTrack(from: oldURL, to: newURL)
            let oldStdPath = oldURL.standardizedFileURL.path
            if let idx = self.tracks.firstIndex(where: { $0.fileURL.standardizedFileURL.path == oldStdPath }) {
                let oldTrack = self.tracks[idx]
                let updated = LocalTrack(
                    fileURL: newURL,
                    title: oldTrack.title,
                    artist: oldTrack.artist,
                    album: oldTrack.album,
                    duration: oldTrack.duration,
                    artworkReference: oldTrack.artworkReference,
                    artworkData: oldTrack.artworkData,
                    trackNumber: oldTrack.trackNumber,
                    year: oldTrack.year
                )
                self.tracks[idx] = updated
            }
            self.updateCachedPresentations()
        }
    }

    public func deleteAlbum(title: String, artist: String, deletePhysical: Bool = false) async {
        let trackIDsToDelete: Set<String>
        do {
            trackIDsToDelete = Set(try await repository.fetchTracks(matchingAlbum: title, artist: artist).map(\.id))
        } catch {
            errorMessage = error.localizedDescription
            return
        }

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
            self.scheduleSpotlightRefresh()
        }
    }

    public func deleteArtist(name: String, deletePhysical: Bool = false) async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let affectedTracks: [LocalTrack]
        do {
            affectedTracks = try await repository.fetchTracks(matchingArtist: cleanName)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        var trackIDsToDelete = Set<String>()
        var tracksToUpdate = [LocalTrack]()

        for track in affectedTracks {
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
            self.scheduleSpotlightRefresh()
        }
    }

    private func deregisterTracks(_ tracks: [LocalTrack]) {
        // Clear in-memory references
    }

    // MARK: - Re-identification & Artwork Resolution

    @discardableResult
    public func reidentifyTrack(trackID: String) async -> Bool {
        let track: LocalTrack
        do {
            guard let found = try await repository.fetchTracks(withIDs: [trackID]).first else { return false }
            track = found
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

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
        if let index = tracks.firstIndex(where: { $0.id == updatedTrack.id }) {
            tracks[index] = updatedTrack
        }
        updateCachedPresentations()
        scheduleSpotlightRefresh()
        return true
    }

    @discardableResult
    public func reidentifyAlbum(albumTitle: String, artist: String) async -> Bool {
        let matchingTracks: [LocalTrack]
        do {
            matchingTracks = try await repository.fetchTracks(matchingAlbum: albumTitle, artist: artist)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        let cleanArt = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let first = matchingTracks.first else { return false }

        guard let result = await LocalArtworkExtractor.resolveRemoteArtwork(
            artist: artist,
            album: albumTitle,
            title: first.title
        ) else {
            return false
        }

        let artRef = LocalArtworkStorage.shared.storeArtwork(result.data)
        var modifiedTracks: [LocalTrack] = []

        for t in matchingTracks {
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
        scheduleSpotlightRefresh()
        return true
    }

    public func saveTracksInPlace(_ updatedTracks: [LocalTrack]) async throws {
        try await repository.saveTracksInPlace(updatedTracks)
        for updated in updatedTracks {
            if let index = tracks.firstIndex(where: { $0.id == updated.id }) {
                tracks[index] = updated
            }
        }
        updateCachedPresentations()
        scheduleSpotlightRefresh()
        revision += 1
    }

    /// Re-reads physical tags, applies online enrichment via Apple Catalog,
    /// and overwrites library records in-place without creating duplicate assets.
    @discardableResult
    public func refreshMetadata(for targetTracks: [LocalTrack]) async throws -> [LocalTrack] {
        guard !targetTracks.isEmpty else { return [] }
        await loadIfNeeded()

        var updatedTracks: [LocalTrack] = []

        // Group selected tracks by directory/album to enable batch album alignment
        var tracksByFolder: [URL: [LocalTrack]] = [:]
        for track in targetTracks {
            let folder = track.fileURL.deletingLastPathComponent()
            tracksByFolder[folder, default: []].append(track)
        }

        for (folder, folderTracks) in tracksByFolder {
            var reReadTracks: [LocalTrack] = []
            for track in folderTracks {
                if let fresh = try? await repository.readTrack(from: track.fileURL) {
                    reReadTracks.append(fresh)
                } else {
                    reReadTracks.append(track)
                }
            }

            let folderName = folder.lastPathComponent
            let primaryArtist = reReadTracks.compactMap { $0.artist }.first(where: { !$0.isEmpty && $0 != "Unknown Artist" })
                ?? folderTracks.first?.artist ?? "Unknown Artist"
            let commonAlbum = reReadTracks.compactMap { $0.album }.first(where: { !$0.isEmpty && $0 != "Unknown Album" })
            let albumHint = commonAlbum ?? MetadataSanitizer.cleanAlbumTitle(folderName, artist: primaryArtist)

            var alignedMap: [URL: LocalTrack] = [:]
            var canonicalAlbumName: String?
            var officialArtworkRef: String?

            if let (alignedList, canonicalAlbum, albumArtRef) = await AppleCatalogService.shared.alignAlbum(
                artistHint: primaryArtist,
                albumHint: albumHint,
                localTracks: reReadTracks
            ) {
                canonicalAlbumName = canonicalAlbum
                officialArtworkRef = albumArtRef
                for aligned in alignedList {
                    alignedMap[aligned.fileURL] = aligned
                }
            }

            var companionArtworkRef: String?
            if officialArtworkRef == nil {
                if let folderArtData = LocalArtworkExtractor.extractFromDirectory(folderURL: folder) {
                    companionArtworkRef = LocalArtworkStorage.shared.storeArtwork(folderArtData)
                }
            }

            for track in reReadTracks {
                let aligned = alignedMap[track.fileURL]
                let finalTitle = aligned?.title ?? track.title
                let finalArtist = aligned?.artist ?? track.artist
                var finalAlbum = aligned?.album ?? canonicalAlbumName ?? track.album
                let finalTrackNo = aligned?.trackNumber ?? track.trackNumber
                let finalYear = aligned?.year ?? track.year
                var finalArtworkRef = aligned?.artworkReference ?? officialArtworkRef ?? track.artworkReference ?? companionArtworkRef

                if finalArtworkRef == nil {
                    if let remote = await LocalArtworkExtractor.resolveRemoteArtwork(artist: finalArtist, album: finalAlbum, title: finalTitle) {
                        finalArtworkRef = LocalArtworkStorage.shared.storeArtwork(remote.data)
                        if finalAlbum == nil, let can = remote.canonicalAlbum {
                            finalAlbum = can
                        }
                    }
                }

                if let alb = finalAlbum, alb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == finalArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                    finalAlbum = canonicalAlbumName
                }

                let updated = LocalTrack(
                    fileURL: track.fileURL,
                    title: finalTitle,
                    artist: finalArtist,
                    album: finalAlbum,
                    duration: track.duration,
                    artworkReference: finalArtworkRef,
                    trackNumber: finalTrackNo,
                    year: finalYear
                )
                updatedTracks.append(updated)
            }
        }

        if !updatedTracks.isEmpty {
            try await saveTracksInPlace(updatedTracks)
        }

        return updatedTracks
    }

    @discardableResult
    public func remediateLibraryMetadataAndArtwork(progress: ((Int, Int) -> Void)? = nil) async -> (repairedCount: Int, artworkAddedCount: Int) {
        await loadIfNeeded()
        guard didLoad else { return (0, 0) }
        var repaired = 0
        var artworkAdded = 0
        var anyUpdates = false
        var afterPath: String?
        var processed = 0
        let total = totalTrackCount
        while true {
            let page: LocalMaintenancePage
            do {
                page = try await repository.fetchMaintenancePage(afterPath: afterPath, limit: 128)
            } catch {
                errorMessage = error.localizedDescription
                return (repaired, artworkAdded)
            }
            guard !page.tracks.isEmpty else { break }
            afterPath = page.nextPath
            var updatedTracks: [LocalTrack] = []
            var pageArtworkAdded = 0

            for currentTrack in page.tracks {
                processed += 1
                progress?(processed, total)

            var modified = false
            var newTitle = currentTrack.title
            var newArtist = currentTrack.artist
            var newAlbum = currentTrack.album
            var newYear = currentTrack.year
            var newTrackNo = currentTrack.trackNumber
            var newArtRef = currentTrack.artworkReference

            // 1. Re-read tags from file if accessible
            let fileExists = FileManager.default.fileExists(atPath: currentTrack.fileURL.path)
            if fileExists {
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
                        pageArtworkAdded += 1
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
                    pageArtworkAdded += 1
                    modified = true
                }
            }

            // 4. Remote artwork resolution fallback (Apple Music prioritized + MusicBrainz)
            if fileExists && newArtRef == nil {
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
                    pageArtworkAdded += 1
                    modified = true
                }
            }

            // 5. Apple Music Catalog Alignment for anomalous tracks or missing albums
            if fileExists && (MetadataSanitizer.isAnomalousTitle(newTitle) || (newAlbum == nil && currentTrack.album != currentTrack.artist)) {
                let folderName = currentTrack.fileURL.deletingLastPathComponent().lastPathComponent
                let albumHint = newAlbum ?? MetadataSanitizer.cleanAlbumTitle(folderName, artist: newArtist)
                if let (alignedTracks, canonicalAlb, art) = await AppleCatalogService.shared.alignAlbum(
                    artistHint: newArtist,
                    albumHint: albumHint,
                    localTracks: [LocalTrack(
                        fileURL: currentTrack.fileURL,
                        title: newTitle,
                        artist: newArtist,
                        album: newAlbum,
                        duration: currentTrack.duration,
                        artworkReference: newArtRef,
                        trackNumber: newTrackNo,
                        year: newYear
                    )]
                ), let aligned = alignedTracks.first {
                    if aligned.title != newTitle {
                        newTitle = aligned.title
                        modified = true
                    }
                    if let a = canonicalAlb, a != newAlbum {
                        newAlbum = a
                        modified = true
                    }
                    if let tNo = aligned.trackNumber, tNo != newTrackNo {
                        newTrackNo = tNo
                        modified = true
                    }
                    if newArtRef == nil, let artRef = art ?? aligned.artworkReference {
                        newArtRef = artRef
                        pageArtworkAdded += 1
                        modified = true
                    }
                }
            }

            if modified {
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
                    return (repaired, artworkAdded)
                }
                repaired += updatedTracks.count
                artworkAdded += pageArtworkAdded
                anyUpdates = true
                let updatedByID = Dictionary(uniqueKeysWithValues: updatedTracks.map { ($0.id, $0) })
                for index in tracks.indices {
                    if let updated = updatedByID[tracks[index].id] {
                        tracks[index] = updated
                    }
                }
            }
        }
        if anyUpdates {
            updateCachedPresentations()
            scheduleSpotlightRefresh()
        }

        return (repaired, artworkAdded)
    }

    public func importFiles(_ urls: [URL]) async {
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
            let result = try await repository.importTracksDetailed(from: urls)
            let page = try await repository.fetchPage(LocalTrackPageRequest(limit: 128))
            tracks = page.tracks
            totalTrackCount = page.totalCount
            isFullyLoaded = page.totalCount <= page.tracks.count
            updateCachedPresentations()
            scheduleSpotlightRefresh()
            await LocalLibraryIndexingService.shared.enqueue(result.tracks)
            triggerBackgroundArtworkBackfillIfNeeded()
            if !result.failures.isEmpty {
                let names = result.failures.prefix(3).map { $0.fileURL.lastPathComponent }.joined(separator: ", ")
                errorMessage = "Imported \(result.tracks.count) tracks; \(result.failures.count) failed (\(names)). The failed files remain in place."
            }
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
    public func triggerBackgroundArtworkBackfillIfNeeded() {
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
                    self.scheduleSpotlightRefresh()
                    print("[ArtworkBackfill] Backfilled artwork for album: [\(group.album ?? "Unknown")] (\(updatedBatch.count) tracks)")
                }
            }

            self.backfillTask = nil
            print("[ArtworkBackfill] Background backfill completed.")
        }
    }
}
