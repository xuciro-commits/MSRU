//
//  PlaylistTests.swift
//  MSRUTests
//
//  Canonical playlist tests protecting creation, track sequencing,
//  deletion, default seeding, and JSON persistence round-trips.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
@Suite("Playlist Management & Persistence Contracts")
struct PlaylistTests {

    @Test
    func playlistStoreSeedsDefaultFavoritesWhenEmpty() async {
        // Arrange: In-memory repository with no existing playlists
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)

        // Act
        await store.load()

        // Assert: Automatically seeds pinned "Favorites"
        #expect(store.playlists.count == 1)
        #expect(store.playlists.first?.title == "Favorites")
        #expect(store.playlists.first?.isPinned == true)
    }

    @Test
    func playlistStoreCreatesAndDeletesPlaylists() async {
        // Arrange
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        // Act 1: Create a custom playlist
        let created = await store.createPlaylist(
            title: "2000s Classics",
            description: "Golden age of Mandopop",
            initialTrackIDs: ["rec_sunny"],
            isPinned: true
        )

        // Assert 1: Custom playlist inserted at front
        #expect(store.playlists.contains { $0.id == created.id })
        #expect(created.title == "2000s Classics")
        #expect(created.trackIDs == ["rec_sunny"])

        // Act 2: Delete the custom playlist
        await store.deletePlaylist(id: created.id)

        // Assert 2: Playlist deleted from store
        #expect(!store.playlists.contains { $0.id == created.id })
    }

    @Test
    func playlistStoreTracksManipulation() async {
        // Arrange
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        let playlist = await store.createPlaylist(title: "Track Ops Test")

        // Act 1: Add tracks
        await store.addTrack("trk_1", to: playlist.id)
        await store.addTrack("trk_2", to: playlist.id)
        await store.addTrack("trk_3", to: playlist.id)

        let updated1 = store.playlists.first { $0.id == playlist.id }
        #expect(updated1?.trackIDs == ["trk_1", "trk_2", "trk_3"])

        // Act 2: Remove trk_2
        await store.removeTrack("trk_2", from: playlist.id)

        let updated2 = store.playlists.first { $0.id == playlist.id }
        #expect(updated2?.trackIDs == ["trk_1", "trk_3"])
    }

    @Test
    func jsonPlaylistRepositoryRoundTripPersistence() async throws {
        // Arrange: Temporary isolated JSON file
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("playlists_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let originalPlaylists = [
            Playlist(
                title: "Road Trip",
                description: "Upbeat drives",
                trackIDs: ["track_a", "track_b"],
                isPinned: true
            ),
            Playlist(
                title: "Late Night Lo-Fi",
                description: "Chill beats",
                trackIDs: ["track_c"]
            )
        ]

        // Act 1: Save through JSON repository
        let repo1 = JSONPlaylistRepository(fileURL: tempFile)
        try await repo1.savePlaylists(originalPlaylists)

        // Act 2: Load through a fresh JSON repository instance
        let repo2 = JSONPlaylistRepository(fileURL: tempFile)
        let loaded = try await repo2.loadPlaylists()

        // Assert: Data matches original exactly
        #expect(loaded.count == 2)
        #expect(loaded[0].title == "Road Trip")
        #expect(loaded[0].description == "Upbeat drives")
        #expect(loaded[0].trackIDs == ["track_a", "track_b"])
        #expect(loaded[0].isPinned == true)
        #expect(loaded[1].title == "Late Night Lo-Fi")
        #expect(loaded[1].trackIDs == ["track_c"])
    }
}
