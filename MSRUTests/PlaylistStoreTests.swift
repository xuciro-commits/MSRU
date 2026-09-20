//
//  PlaylistStoreTests.swift
//  MSRUTests
//

import Testing
import Foundation
@testable import MSRU

@Suite("Playlist Store & Persistence Tests")
struct PlaylistStoreTests {

    @Test("Loading empty repository seeds default Favorites playlist")
    @MainActor
    func testLoadingEmptyStoreSeedsFavorites() async {
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)

        #expect(!store.hasLoaded)
        await store.load()
        #expect(store.hasLoaded)
        #expect(store.playlists.count == 1)
        #expect(store.playlists[0].title == "Favorites")
        #expect(store.playlists[0].isPinned == true)
    }

    @Test("Creating and updating playlist properties")
    @MainActor
    func testCreateAndUpdatePlaylist() async {
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        let created = await store.createPlaylist(
            title: "Road Trip",
            description: "High energy tracks for the highway",
            isPinned: false
        )

        #expect(store.playlists.count == 2)
        #expect(store.playlists[0].id == created.id)
        #expect(store.playlists[0].title == "Road Trip")
        #expect(store.playlists[0].description == "High energy tracks for the highway")

        // Update
        await store.updatePlaylist(
            id: created.id,
            title: "Road Trip 2026",
            description: "Updated description",
            isPinned: true
        )

        let updated = store.playlist(for: created.id)
        #expect(updated?.title == "Road Trip 2026")
        #expect(updated?.description == "Updated description")
        #expect(updated?.isPinned == true)
    }

    @Test("Adding and removing tracks in playlist")
    @MainActor
    func testAddAndRemoveTracks() async {
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        let playlist = await store.createPlaylist(title: "Ambient Chill")
        let track1 = "track-1"
        let track2 = "track-2"
        let track3 = "track-3"

        // Add single track
        await store.addTrack(track1, to: playlist.id)
        #expect(store.contains(trackID: track1, in: playlist.id))
        #expect(store.playlist(for: playlist.id)?.trackCount == 1)

        // Duplicate add is ignored
        await store.addTrack(track1, to: playlist.id)
        #expect(store.playlist(for: playlist.id)?.trackCount == 1)

        // Add multiple tracks
        await store.addTracks([track2, track3], to: playlist.id)
        #expect(store.playlist(for: playlist.id)?.trackCount == 3)
        #expect(store.playlist(for: playlist.id)?.trackIDs == [track1, track2, track3])

        // Remove track
        await store.removeTrack(track2, from: playlist.id)
        #expect(!store.contains(trackID: track2, in: playlist.id))
        #expect(store.playlist(for: playlist.id)?.trackIDs == [track1, track3])
    }

    @Test("Reordering tracks and deleting playlist")
    @MainActor
    func testReorderTracksAndDeletePlaylist() async {
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        let t1 = "track-a"
        let t2 = "track-b"
        let t3 = "track-c"
        let playlist = await store.createPlaylist(title: "Order Test", initialTrackIDs: [t1, t2, t3])

        #expect(store.playlist(for: playlist.id)?.trackIDs == [t1, t2, t3])

        // Move t1 to the end
        await store.moveTracks(from: IndexSet(integer: 0), to: 3, in: playlist.id)
        #expect(store.playlist(for: playlist.id)?.trackIDs == [t2, t3, t1])

        // Delete playlist
        await store.deletePlaylist(id: playlist.id)
        #expect(store.playlist(for: playlist.id) == nil)
    }

    @Test("JSON persistence roundtrip to disk")
    @MainActor
    func testJSONPersistenceRoundtrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("playlists_test.json")
        let repo = JSONPlaylistRepository(fileURL: fileURL)
        let store = PlaylistStore(repository: repo)

        await store.load()
        let created = await store.createPlaylist(title: "Persisted Playlist", description: "Safe on disk")
        await store.addTrack("track-alpha", to: created.id)

        // Load fresh store from same fileURL
        let freshRepo = JSONPlaylistRepository(fileURL: fileURL)
        let freshStore = PlaylistStore(repository: freshRepo)
        await freshStore.load()

        let reloaded = freshStore.playlist(for: created.id)
        #expect(reloaded != nil)
        #expect(reloaded?.title == "Persisted Playlist")
        #expect(reloaded?.trackCount == 1)
    }
}
