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
import MusicDomain
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
    func sqlitePlaylistRepositoryRoundTripPersistence() async throws {
        let db = try TestDatabase.makeEphemeral()
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

        // Act 1: Save through SQLite repository
        let repo1 = SQLitePlaylistRepository(db: db)
        try await repo1.savePlaylists(originalPlaylists)

        // Act 2: Load through a fresh SQLite repository instance
        let repo2 = SQLitePlaylistRepository(db: db)
        let loaded = try await repo2.loadPlaylists()

        // Assert: Data matches original exactly
        #expect(loaded.count == 2)
        let first = try #require(loaded.first)
        #expect(first.title == "Road Trip")
        #expect(first.description == "Upbeat drives")
        #expect(first.trackIDs == ["track_a", "track_b"])
        #expect(first.isPinned == true)
        let second = try #require(loaded.count > 1 ? loaded[1] : nil)
        #expect(second.title == "Late Night Lo-Fi")
        #expect(second.trackIDs == ["track_c"])
    }

    @Test
    func sqlitePlaylistRepositoryMigratesLegacyJSON() async throws {
        let db = try TestDatabase.makeEphemeral()
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("playlists_legacy_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let legacyPlaylist = Playlist(
            title: "Legacy Party",
            description: "From JSON",
            trackIDs: ["legacy_trk_1"]
        )
        let data = try JSONEncoder().encode([legacyPlaylist])
        try data.write(to: tempFile)

        // Initializing repository with legacyFileURL should import to SQLite and delete legacy file
        let repo = SQLitePlaylistRepository(db: db, legacyFileURL: tempFile)
        let loaded = try await repo.loadPlaylists()

        #expect(loaded.count == 1)
        let migrated = try #require(loaded.first)
        #expect(migrated.title == "Legacy Party")
        #expect(migrated.trackIDs == ["legacy_trk_1"])
        #expect(!FileManager.default.fileExists(atPath: tempFile.path))
        #expect(FileManager.default.fileExists(atPath: tempFile.appendingPathExtension("legacy.backup").path))
    }

    @Test
    func sqlitePlaylistChangesPreserveUnrelatedRows() async throws {
        let db = try TestDatabase.makeEphemeral()
        let repo = SQLitePlaylistRepository(db: db)
        let first = Playlist(title: "First", trackIDs: ["a", "b"])
        let second = Playlist(title: "Second", trackIDs: ["c"])
        try await repo.savePlaylists([first, second])

        var changed = first
        changed.title = "Renamed"
        try await repo.applyChanges(upserting: [changed], deleting: [])

        let loaded = try await repo.loadPlaylists()
        #expect(loaded.first(where: { $0.id == changed.id })?.title == "Renamed")
        #expect(loaded.first(where: { $0.id == second.id })?.trackIDs == ["c"])
    }

    @Test
    func malformedLegacyPlaylistRemainsRecoverable() async throws {
        let db = try TestDatabase.makeEphemeral()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("playlists_corrupt_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{broken".utf8).write(to: url)

        let repo = SQLitePlaylistRepository(db: db, legacyFileURL: url)
        await #expect(throws: (any Error).self) { _ = try await repo.loadPlaylists() }
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: url.appendingPathExtension("legacy.backup").path))
    }

    @Test
    func failedPlaylistWriteDoesNotChangeVisibleState() async {
        let repo = FailingPlaylistRepository()
        let store = PlaylistStore(repository: repo)
        await store.load()
        #expect(store.playlists.isEmpty)
        #expect(store.errorMessage != nil)

        _ = await store.createPlaylist(title: "Will Fail")
        #expect(store.playlists.isEmpty)
        #expect(store.errorMessage != nil)
    }
}

@MainActor
private final class FailingPlaylistRepository: PlaylistRepository, @unchecked Sendable {
    func loadPlaylists() async throws -> [Playlist] { [] }
    func savePlaylists(_ playlists: [Playlist]) async throws { throw Failure.write }
    func applyChanges(upserting playlists: [Playlist], deleting ids: Set<UUID>) async throws {
        throw Failure.write
    }

    private enum Failure: Error { case write }
}
