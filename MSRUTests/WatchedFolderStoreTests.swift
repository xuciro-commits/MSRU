//
//  WatchedFolderStoreTests.swift
//  MSRUTests
//
//  Created for Task 31: Watched Folders background monitoring and continuous ingestion.
//

import Testing
import Foundation
@testable import MSRU

@Suite("Watched Folder Store & Ingestion Tests")
@MainActor
struct WatchedFolderStoreTests {

    @Test("WatchedFolder Codable roundtrip preserves all properties")
    func testWatchedFolderCodableRoundtrip() throws {
        let original = WatchedFolder(
            id: UUID(),
            url: URL(fileURLWithPath: "/Volumes/Media/Music/Artists"),
            bookmarkData: "sample-bookmark".data(using: .utf8),
            isEnabled: true,
            autoIngest: true,
            lastScannedAt: Date(timeIntervalSince1970: 1700000000),
            trackCount: 42
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchedFolder.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.url.path == original.url.path)
        #expect(decoded.bookmarkData == original.bookmarkData)
        #expect(decoded.isEnabled == original.isEnabled)
        #expect(decoded.autoIngest == original.autoIngest)
        #expect(decoded.trackCount == 42)
        #expect(decoded.displayName == "Artists")
    }

    @Test("Adding and removing watched folders with persistence")
    @MainActor
    func testAddAndRemoveWatchedFolders() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestURL = tempDir.appendingPathComponent("watched_folders.json")
        let simulatedDriver = SimulatedFolderWatcherDriver()
        let watcherService = FolderWatcherService(driverFactory: { simulatedDriver })
        let localStore = LocalLibraryStore(repository: PreviewTestLibraryRepository())

        let store = WatchedFolderStore(
            localStore: localStore,
            watcherService: watcherService,
            manifestURL: manifestURL,
            seedDefaultFolder: false
        )

        let folderA = tempDir.appendingPathComponent("FolderA", isDirectory: true)
        try FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)

        await store.addFolder(url: folderA, autoIngest: true)
        #expect(store.folders.count == 1)
        #expect(store.folders[0].url.standardizedFileURL.path == folderA.standardizedFileURL.path)
        #expect(store.folders[0].isEnabled == true)
        #expect(store.folders[0].autoIngest == true)

        // Verify persistence
        let store2 = WatchedFolderStore(
            localStore: localStore,
            watcherService: watcherService,
            manifestURL: manifestURL,
            seedDefaultFolder: false
        )
        #expect(store2.folders.count == 1)
        #expect(store2.folders[0].id == store.folders[0].id)

        // Toggle folder
        let folderID = store.folders[0].id
        store.toggleFolder(id: folderID)
        #expect(store.folders[0].isEnabled == false)

        // Remove folder
        store.removeFolder(id: folderID)
        #expect(store.folders.isEmpty)

        // Verify removed from persistence
        let store3 = WatchedFolderStore(
            localStore: localStore,
            watcherService: watcherService,
            manifestURL: manifestURL,
            seedDefaultFolder: false
        )
        #expect(store3.folders.isEmpty)
    }

    @Test("Simulated file change triggers ingestion and updates track count")
    @MainActor
    func testWatcherIngestionWorkflow() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let watchFolder = tempDir.appendingPathComponent("WatchFolder", isDirectory: true)
        try FileManager.default.createDirectory(at: watchFolder, withIntermediateDirectories: true)

        let manifestURL = tempDir.appendingPathComponent("watched_folders.json")
        let simulatedDriver = SimulatedFolderWatcherDriver()
        let watcherService = FolderWatcherService(driverFactory: { simulatedDriver })
        let localStore = LocalLibraryStore(repository: PreviewTestLibraryRepository())

        let store = WatchedFolderStore(
            localStore: localStore,
            watcherService: watcherService,
            manifestURL: manifestURL,
            seedDefaultFolder: false
        )

        await store.addFolder(url: watchFolder, autoIngest: true)
        #expect(store.folders.count == 1)

        // Create a fake audio file in the watched folder
        let sampleTrackURL = watchFolder.appendingPathComponent("Song1.wav")
        let dummyWAVData = Data([0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45])
        try dummyWAVData.write(to: sampleTrackURL)

        // Trigger change via driver
        simulatedDriver.triggerChange()

        // Wait for scan
        await store.rescanFolder(id: store.folders[0].id)

        #expect(store.folders[0].trackCount == 1)
        #expect(store.folders[0].lastScannedAt != nil)
        #expect(localStore.tracks.count == 1)
        #expect(localStore.tracks[0].title == "Song1")
    }
}

@MainActor
private final class PreviewTestLibraryRepository: LocalLibraryRepository {
    private var inMemoryTracks: [LocalTrack] = []

    func loadTracks() async throws -> [LocalTrack] {
        inMemoryTracks
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        let track = LocalTrack(fileURL: url, title: url.deletingPathExtension().lastPathComponent, artist: "Test Artist")
        inMemoryTracks.append(track)
        return track
    }

    func saveTrackInPlace(_ track: LocalTrack) async throws {
        if let idx = inMemoryTracks.firstIndex(where: { $0.id == track.id }) {
            inMemoryTracks[idx] = track
        } else {
            inMemoryTracks.append(track)
        }
    }

    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        inMemoryTracks.removeAll { ids.contains($0.id) }
    }

    func readTrack(from url: URL) async throws -> LocalTrack {
        LocalTrack(
            fileURL: url,
            title: url.deletingPathExtension().lastPathComponent,
            artist: "Test Artist",
            album: "Test Album",
            duration: 180
        )
    }
}
