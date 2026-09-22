//
//  LocalLibraryLifecycleTests.swift
//  MSRUTests
//
//  Acceptance tests for Local Library Lifecycle, Hydration, Watched Folder Reconciliation,
//  Asset Caching, and Batch Persistence.
//

import Foundation
import Testing
@testable import MSRU

@MainActor
struct LocalLibraryLifecycleTests {

    private final class MockManifestRepository: LocalLibraryRepository, @unchecked Sendable {
        var persistedTracks: [LocalTrack] = []
        var saveCallCount: Int = 0
        var shouldFailSave: Bool = false

        init(initialTracks: [LocalTrack] = []) {
            self.persistedTracks = initialTracks
        }

        func loadTracks() async throws -> [LocalTrack] {
            persistedTracks
        }

        func importTrack(from url: URL) async throws -> LocalTrack? {
            nil
        }

        func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {
            if shouldFailSave {
                throw NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Simulated disk write failure"])
            }
            saveCallCount += 1
            for track in tracks {
                if let idx = persistedTracks.firstIndex(where: { $0.id == track.id || $0.fileURL == track.fileURL }) {
                    persistedTracks[idx] = track
                } else {
                    persistedTracks.append(track)
                }
            }
        }

        func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
            persistedTracks.removeAll { ids.contains($0.id) || ids.contains($0.fileURL.path) }
        }
    }

    @Test
    func test_unchangedLibraryReconciliation_producesZeroReadsAndZeroWrites() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)

        var initialTracks: [LocalTrack] = []
        for i in 1...10 {
            let fileURL = tempDir.appendingPathComponent("track_\(i).flac")
            try Data(repeating: UInt8(i), count: 1024).write(to: fileURL)
            let track = LocalTrack(fileURL: fileURL, title: "Track \(i)", artist: "Artist", duration: 180.0)
            initialTracks.append(track)
            await registry.register(
                fingerprint: "fp_\(i)",
                duration: 180.0,
                title: track.title,
                artist: track.artist,
                fileURL: fileURL
            )
        }

        let repo = MockManifestRepository(initialTracks: initialTracks)
        let db = try AppDatabase.makeEphemeral()
        let store = LocalLibraryStore(repository: repo, db: db)

        // 1. Hydrate
        await store.loadIfNeeded()
        #expect(store.tracks.count == 10)
        #expect(repo.saveCallCount == 0)

        // 2. Reconcile unchanged folder
        let scanner = WatchedFolderScanner()
        let cache = await registry.assetCache
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: cache
        )

        // Acceptance criterion: 0 new, 0 modified, 0 deleted, 0 writes
        #expect(result.newTracks.isEmpty)
        #expect(result.modifiedTracks.isEmpty)
        #expect(result.deletedTrackPaths.isEmpty)
        #expect(result.discoveredCount == 0)
        #expect(repo.saveCallCount == 0)
    }

    @Test
    func test_addedFilesReconciliation_onlyIngestsNewFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)

        var initialTracks: [LocalTrack] = []
        for i in 1...5 {
            let fileURL = tempDir.appendingPathComponent("existing_\(i).flac")
            try Data(repeating: UInt8(i), count: 1024).write(to: fileURL)
            let track = LocalTrack(fileURL: fileURL, title: "Track \(i)", artist: "Artist", duration: 180.0)
            initialTracks.append(track)
            await registry.register(
                fingerprint: "fp_\(i)",
                duration: 180.0,
                title: track.title,
                artist: track.artist,
                fileURL: fileURL
            )
        }

        // Add 2 brand new files to the directory
        let newFile1 = tempDir.appendingPathComponent("new_1.flac")
        let newFile2 = tempDir.appendingPathComponent("new_2.flac")
        try Data(repeating: 0x99, count: 1024).write(to: newFile1)
        try Data(repeating: 0x9A, count: 1024).write(to: newFile2)

        let repo = MockManifestRepository(initialTracks: initialTracks)
        let db = try AppDatabase.makeEphemeral()
        let store = LocalLibraryStore(repository: repo, db: db)
        await store.loadIfNeeded()

        let scanner = WatchedFolderScanner()
        let cache = await registry.assetCache
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: cache
        )

        #expect(result.newTracks.count == 2)
        #expect(result.modifiedTracks.isEmpty)
        #expect(result.deletedTrackPaths.isEmpty)
        #expect(result.discoveredCount == 2)

        // Ingest the 2 newly discovered tracks in a single batch
        try await store.addTracks(result.newTracks)
        #expect(store.tracks.count == 7)
        #expect(repo.saveCallCount == 1) // Exactly one atomic batch write!
    }

    @Test
    func test_modifiedFileReconciliation_detectsModification() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)

        let fileURL = tempDir.appendingPathComponent("track.flac")
        try Data(repeating: 0x11, count: 1024).write(to: fileURL)

        let track = LocalTrack(fileURL: fileURL, title: "Original Title", artist: "Artist", duration: 120.0)
        await registry.register(
            fingerprint: "fp_original",
            duration: 120.0,
            title: track.title,
            artist: track.artist,
            fileURL: fileURL
        )

        #expect(await registry.hasValidRecord(for: fileURL))

        // Modify file on disk: change file size
        try Data(repeating: 0x22, count: 2048).write(to: fileURL)

        // Asset cache must now detect invalidation
        #expect(await !registry.hasValidRecord(for: fileURL))

        let repo = MockManifestRepository(initialTracks: [track])
        let db = try AppDatabase.makeEphemeral()
        let store = LocalLibraryStore(repository: repo, db: db)
        await store.loadIfNeeded()

        let scanner = WatchedFolderScanner()
        let cache = await registry.assetCache
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: cache
        )

        #expect(result.newTracks.isEmpty)
        #expect(result.modifiedTracks.count == 1)
        #expect(result.discoveredCount == 1)
    }

    @Test
    func test_deletedFileReconciliation_removesFromLibrary() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("keep.flac")
        let file2 = tempDir.appendingPathComponent("delete_me.flac")
        try Data("keep".utf8).write(to: file1)
        try Data("delete".utf8).write(to: file2)

        let track1 = LocalTrack(fileURL: file1, title: "Keep", artist: "Artist", duration: 100)
        let track2 = LocalTrack(fileURL: file2, title: "Delete Me", artist: "Artist", duration: 100)

        let repo = MockManifestRepository(initialTracks: [track1, track2])
        let db = try AppDatabase.makeEphemeral()
        let store = LocalLibraryStore(repository: repo, db: db)
        await store.loadIfNeeded()
        #expect(store.tracks.count == 2)

        // Delete file2 physically from disk
        try FileManager.default.removeItem(at: file2)

        let scanner = WatchedFolderScanner()
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: [:]
        )

        #expect(result.newTracks.isEmpty)
        #expect(result.modifiedTracks.isEmpty)
        #expect(result.deletedTrackPaths.count == 1)
        #expect(result.deletedTrackPaths.first == file2.standardizedFileURL.path)

        // Reconcile deletion in store
        await store.deleteTracks(withIDs: Set(result.deletedTrackPaths))
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.title == "Keep")
    }

    @Test
    func test_batchIngestion_savesManifestExactlyOnce() async throws {
        let repo = MockManifestRepository()
        let db = try AppDatabase.makeEphemeral()
        let store = LocalLibraryStore(repository: repo, db: db)

        var tracks: [LocalTrack] = []
        for i in 1...100 {
            tracks.append(LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/track_\(i).flac"),
                title: "Track \(i)",
                artist: "Artist",
                duration: Double(i)
            ))
        }

        try await store.addTracks(tracks)
        #expect(store.tracks.count == 100)
        #expect(repo.saveCallCount == 1) // Crucial: NOT 100 calls!
    }

    @Test
    func test_failedPersistence_doesNotMutateInMemoryTracks() async {
        let repo = MockManifestRepository()
        repo.shouldFailSave = true

        let db = (try? AppDatabase.makeEphemeral()) ?? AppDatabase.shared
        let store = LocalLibraryStore(repository: repo, db: db)
        let track = LocalTrack(fileURL: URL(fileURLWithPath: "/music/fail.flac"), title: "Fail", artist: "Artist", duration: 100)

        var didCatchError = false
        do {
            try await store.addTracks([track])
        } catch {
            didCatchError = true
        }

        #expect(didCatchError)
        #expect(store.tracks.isEmpty) // Memory state preserved!
        #expect(store.errorMessage != nil)
    }

    @Test
    func test_twoDistinctPathsSharingSameAcousticFingerprint() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)

        let path1 = tempDir.appendingPathComponent("disc1_track1.flac")
        let path2 = tempDir.appendingPathComponent("best_of_track1.flac")
        try Data("audio data 1".utf8).write(to: path1)
        try Data("audio data 2".utf8).write(to: path2)

        let commonFP = "shared_stream_fingerprint_xyz"

        await registry.register(
            fingerprint: commonFP,
            duration: 210.0,
            title: "Hit Song",
            artist: "Famous Artist",
            fileURL: path1
        )
        await registry.register(
            fingerprint: commonFP,
            duration: 210.0,
            title: "Hit Song",
            artist: "Famous Artist",
            fileURL: path2
        )

        // Only one fingerprint record
        #expect(await registry.records.count == 1)
        #expect(await registry.records.first?.fingerprint == commonFP)

        // Two distinct asset entries both resolving to the common fingerprint
        #expect(await registry.cachedFingerprint(for: path1) == commonFP)
        #expect(await registry.cachedFingerprint(for: path2) == commonFP)
        #expect(await registry.hasValidRecord(for: path1))
        #expect(await registry.hasValidRecord(for: path2))

        // Reopening registry preserves both asset cache records
        let reopened = LocalFingerprintRegistry(storageURL: regStorage)
        #expect(await reopened.records.count == 1)
        #expect(await reopened.cachedFingerprint(for: path1) == commonFP)
        #expect(await reopened.cachedFingerprint(for: path2) == commonFP)
    }
}

// MARK: - Suspended Local Repository for Ordering Tests

@MainActor
private final class SuspendedLocalRepository: LocalLibraryRepository {
    var tracks: [LocalTrack] = []
    var started: (() -> Void)?
    var release: CheckedContinuation<Void, Never>?
    var suspendLoad = false
    var suspendImport = false
    var imports = 0

    func loadTracks() async throws -> [LocalTrack] {
        let snapshot = tracks
        if suspendLoad {
            suspendLoad = false
            await withCheckedContinuation { release = $0; started?() }
        }
        return snapshot
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        imports += 1
        if suspendImport {
            suspendImport = false
            await withCheckedContinuation { release = $0; started?() }
        }
        let track = LocalTrack(fileURL: url, title: url.lastPathComponent, artist: "Fixture",
                               album: nil, duration: 1, artworkData: nil)
        tracks.append(track)
        return track
    }
}

@MainActor
struct LocalLibraryOrderingTests {
    @Test
    func suspendedScanCannotOverwriteLaterImport() async {
        let repository = SuspendedLocalRepository()
        repository.suspendLoad = true
        let db = (try? AppDatabase.makeEphemeral()) ?? AppDatabase.shared
        let store = LocalLibraryStore(repository: repository, db: db)
        var loading: Task<Void, Never>?
        await withCheckedContinuation { started in
            repository.started = { started.resume() }
            loading = Task { await store.loadIfNeeded() }
        }
        var importing: Task<Void, Never>?
        await withCheckedContinuation { queued in
            importing = Task { @MainActor in
                queued.resume()
                await store.importFiles([URL(fileURLWithPath: "/fixture/new.wav")])
            }
        }
        #expect(repository.imports == 0)
        repository.release?.resume()
        repository.release = nil
        await loading?.value
        await importing?.value
        #expect(store.tracks.map(\.title) == ["new.wav"])
        #expect(store.tracks == repository.tracks)
    }

    @Test
    func secondImportIsQueuedInsteadOfSilentlyDiscarded() async {
        let repository = SuspendedLocalRepository()
        repository.suspendImport = true
        let db = (try? AppDatabase.makeEphemeral()) ?? AppDatabase.shared
        let store = LocalLibraryStore(repository: repository, db: db)
        var first: Task<Void, Never>?
        await withCheckedContinuation { started in
            repository.started = { started.resume() }
            first = Task { await store.importFiles([URL(fileURLWithPath: "/fixture/first.wav")]) }
        }
        var second: Task<Void, Never>?
        await withCheckedContinuation { queued in
            second = Task { @MainActor in
                queued.resume()
                await store.importFiles([URL(fileURLWithPath: "/fixture/second.wav")])
            }
        }
        #expect(store.isImporting)
        #expect(repository.imports == 1)
        repository.release?.resume()
        repository.release = nil
        await first?.value
        await second?.value
        #expect(repository.imports == 2)
        #expect(store.tracks.count == 2)
        #expect(!store.isImporting)
    }
}

// MARK: - Cascade Deletion Tests

@MainActor
private final class MockDeletionRepository: LocalLibraryRepository {
    var tracks: [LocalTrack] = []
    var deletedIDs: Set<String> = []

    func loadTracks() async throws -> [LocalTrack] {
        tracks
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        nil
    }

    func saveTrackInPlace(_ track: LocalTrack) async throws {
        tracks.append(track)
    }

    func saveTracksInPlace(_ newTracks: [LocalTrack]) async throws {
        tracks.append(contentsOf: newTracks)
    }

    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        deletedIDs.formUnion(ids)
        tracks.removeAll { ids.contains($0.id) }
    }
}

@MainActor
struct LocalLibraryCascadeDeletionTests {

    @Test
    func deleteSingleTrackRemovesFromStoreAndRepository() async {
        let repo = MockDeletionRepository()
        let t1 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/track1.flac"), title: "Track 1", artist: "Artist A", album: "Album 1", duration: 180)
        let t2 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/track2.flac"), title: "Track 2", artist: "Artist B", album: "Album 2", duration: 200)

        let db1 = (try? AppDatabase.makeEphemeral()) ?? AppDatabase.shared
        let store = LocalLibraryStore(repository: repo, db: db1)
        try? await store.addTracks([t1, t2])
        #expect(store.tracks.count == 2)

        await store.deleteTracks(withIDs: [t1.id])
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.id == t2.id)
        #expect(repo.deletedIDs.contains(t1.id))
    }

    @Test
    func deleteAlbumCascadesToAllMatchingTracks() async {
        let repo = MockDeletionRepository()
        let t1 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/a1.flac"), title: "早", artist: "万能青年旅店", album: "冀西南林路行", duration: 180)
        let t2 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/a2.flac"), title: "泥河", artist: "万能青年旅店", album: "冀西南林路行", duration: 240)
        let t3 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/b1.flac"), title: "晴天", artist: "周杰伦", album: "叶惠美", duration: 269)

        let db2 = (try? AppDatabase.makeEphemeral()) ?? AppDatabase.shared
        let store = LocalLibraryStore(repository: repo, db: db2)
        try? await store.addTracks([t1, t2, t3])
        #expect(store.tracks.count == 3)

        await store.deleteAlbum(title: "冀西南林路行", artist: "万能青年旅店")
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.title == "晴天")
        #expect(repo.deletedIDs.contains(t1.id))
        #expect(repo.deletedIDs.contains(t2.id))
    }

    @Test
    func deleteArtistCascadesToAllAlbumsAndTracks() async {
        let repo = MockDeletionRepository()
        let t1 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/j1.flac"), title: "以父之名", artist: "周杰伦", album: "叶惠美", duration: 342)
        let t2 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/j2.flac"), title: "晴天", artist: "周杰伦", album: "叶惠美", duration: 269)
        let t3 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/j3.flac"), title: "七里香", artist: "周杰伦", album: "七里香", duration: 299)
        let t4 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/ad1.flac"), title: "Rolling in the Deep", artist: "Adele", album: "21", duration: 228)

        let db3 = (try? AppDatabase.makeEphemeral()) ?? AppDatabase.shared
        let store = LocalLibraryStore(repository: repo, db: db3)
        try? await store.addTracks([t1, t2, t3, t4])
        #expect(store.tracks.count == 4)

        await store.deleteArtist(name: "周杰伦")
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.artist == "Adele")
        #expect(repo.deletedIDs.contains(t1.id))
        #expect(repo.deletedIDs.contains(t2.id))
        #expect(repo.deletedIDs.contains(t3.id))
    }

    @Test
    func metadataProviderConfigStoreFunctionality() {
        let testDefaults = UserDefaults(suiteName: "TestMetadataProviderConfigStore")!
        testDefaults.removePersistentDomain(forName: "TestMetadataProviderConfigStore")
        let config = MetadataProviderConfigStore(userDefaults: testDefaults, defaultsKey: "test_key")
        #expect(config.isEnabled(.appleMusic))
        #expect(config.isEnabled(.musicBrainz))
        #expect(config.isEnabled(.coverArtArchive))
        #expect(config.isEnabled(.localEmbedded))

        config.setEnabled(.musicBrainz, isEnabled: false)
        #expect(!config.isEnabled(.musicBrainz))

        config.setEnabled(.musicBrainz, isEnabled: true)
        #expect(config.isEnabled(.musicBrainz))

        #expect(config.providerPriority.first == .appleMusic)
        config.move(from: IndexSet(integer: 0), to: 2)
        #expect(config.providerPriority.first != .appleMusic)
    }

    @Test
    func cleanOrphanFingerprintsRegistryTest() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = LocalFingerprintRegistry(storageURL: tempDir.appendingPathComponent("test_fp.json"))
        await registry.register(fingerprint: "fp1", duration: 180, title: "Title A", artist: "Artist A")
        await registry.register(fingerprint: "fp2", duration: 200, title: "Title B", artist: "Artist B")
        await registry.register(fingerprint: "fp3", duration: 220, title: "Title C", artist: "Artist C")

        #expect(await registry.records.count == 3)

        let activeTracks = [
            LocalTrack(fileURL: URL(fileURLWithPath: "/dummy/a.flac"), title: "Title A", artist: "Artist A", duration: 180),
            LocalTrack(fileURL: URL(fileURLWithPath: "/dummy/b.flac"), title: "Title B", artist: "Artist B", duration: 200)
        ]

        let cleaned = await registry.cleanOrphanRecords(activeTracks: activeTracks)
        #expect(cleaned == 1)
        #expect(await registry.records.count == 2)
        #expect(await registry.records.contains { $0.title == "Title A" })
        #expect(await registry.records.contains { $0.title == "Title B" })
        #expect(await !registry.records.contains { $0.title == "Title C" })
    }

    @Test
    func fileLocalLibraryRepositoryPhysicalCascadeCleanupTest() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let albumDir = tempDir.appendingPathComponent("Artist X/Album Y", isDirectory: true)
        try FileManager.default.createDirectory(at: albumDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let trackFile = albumDir.appendingPathComponent("01. Song.mp3")
        try Data("dummy mp3 content".utf8).write(to: trackFile)

        let coverFile = albumDir.appendingPathComponent("cover.jpg")
        try Data("dummy cover jpg".utf8).write(to: coverFile)

        let repo = FileLocalLibraryRepository(directory: tempDir)
        let localTrack = LocalTrack(fileURL: trackFile, title: "Song", artist: "Artist X", album: "Album Y", duration: 180)
        try await repo.saveTrackInPlace(localTrack)

        #expect(FileManager.default.fileExists(atPath: trackFile.path))
        #expect(FileManager.default.fileExists(atPath: coverFile.path))

        try await repo.deleteTracks(withIDs: [localTrack.id], deletePhysicalFiles: true)

        #expect(!FileManager.default.fileExists(atPath: trackFile.path))
        #expect(!FileManager.default.fileExists(atPath: coverFile.path))
        #expect(!FileManager.default.fileExists(atPath: albumDir.path))
    }
}
