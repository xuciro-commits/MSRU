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
            registry.register(
                fingerprint: "fp_\(i)",
                duration: 180.0,
                title: track.title,
                artist: track.artist,
                fileURL: fileURL
            )
        }

        let repo = MockManifestRepository(initialTracks: initialTracks)
        let store = LocalLibraryStore(repository: repo)

        // 1. Hydrate
        await store.loadIfNeeded()
        #expect(store.tracks.count == 10)
        #expect(repo.saveCallCount == 0)

        // 2. Reconcile unchanged folder
        let scanner = WatchedFolderScanner()
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: registry.assetCache
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
            registry.register(
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
        let store = LocalLibraryStore(repository: repo)
        await store.loadIfNeeded()

        let scanner = WatchedFolderScanner()
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: registry.assetCache
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
        registry.register(
            fingerprint: "fp_original",
            duration: 120.0,
            title: track.title,
            artist: track.artist,
            fileURL: fileURL
        )

        #expect(registry.hasValidRecord(for: fileURL))

        // Modify file on disk: change file size
        try Data(repeating: 0x22, count: 2048).write(to: fileURL)

        // Asset cache must now detect invalidation
        #expect(!registry.hasValidRecord(for: fileURL))

        let repo = MockManifestRepository(initialTracks: [track])
        let store = LocalLibraryStore(repository: repo)
        await store.loadIfNeeded()

        let scanner = WatchedFolderScanner()
        let result = await scanner.reconcileFolder(
            targetURL: tempDir,
            existingTracksInFolder: store.tracks,
            assetCache: registry.assetCache
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
        let store = LocalLibraryStore(repository: repo)
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
        let store = LocalLibraryStore(repository: repo)

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

        let store = LocalLibraryStore(repository: repo)
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
    func test_twoDistinctPathsSharingSameAcousticFingerprint() throws {
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

        registry.register(
            fingerprint: commonFP,
            duration: 210.0,
            title: "Hit Song",
            artist: "Famous Artist",
            fileURL: path1
        )
        registry.register(
            fingerprint: commonFP,
            duration: 210.0,
            title: "Hit Song",
            artist: "Famous Artist",
            fileURL: path2
        )

        // Only one fingerprint record
        #expect(registry.records.count == 1)
        #expect(registry.records.first?.fingerprint == commonFP)

        // Two distinct asset entries both resolving to the common fingerprint
        #expect(registry.cachedFingerprint(for: path1) == commonFP)
        #expect(registry.cachedFingerprint(for: path2) == commonFP)
        #expect(registry.hasValidRecord(for: path1))
        #expect(registry.hasValidRecord(for: path2))

        // Reopening registry preserves both asset cache records
        let reopened = LocalFingerprintRegistry(storageURL: regStorage)
        #expect(reopened.records.count == 1)
        #expect(reopened.cachedFingerprint(for: path1) == commonFP)
        #expect(reopened.cachedFingerprint(for: path2) == commonFP)
    }
}
