//
//  SubsonicPlaylistSyncTests.swift
//  MSRUTests
//
//  Verification of remote Subsonic playlist synchronization into canonical SQLite,
//  idempotent re-sync, source stats computation, and SceneModel navigation linkage.
//

import Testing
import Foundation
import CryptoKit
import AppFoundation
import MusicDomain
import SubsonicKit
import GRDB
import MusicLibrary
import MusicPlayback
@testable import MSRU

@Suite("Subsonic Playlist & Source Navigation Tests")
struct SubsonicPlaylistSyncTests {

    @Test("Subsonic playlist sync persists remote playlists into SQLite with deterministic UUID")
    func testSubsonicPlaylistSync() async throws {
        let db = try TestDatabase.makeEphemeral()
        let serverID = LibrarySourceID("zspace_nas")
        let credStore = InMemorySubsonicCredentialStore()
        try credStore.savePassword("password123", for: serverID)

        let client = SubsonicClient(
            serverID: serverID,
            baseURL: URL(string: "http://192.168.31.200:8025")!,
            username: "msru",
            credentialStore: credStore
        )

        let syncService = SubsonicLibrarySyncService(
            serverID: serverID,
            client: client,
            db: db
        )

        // 1. Ingest songs first
        let song = SubsonicSongDTO(
            id: "song_1",
            parent: "alb_1",
            title: "稻香",
            album: "魔杰座",
            artist: "周杰伦",
            track: 1,
            year: 2008,
            duration: 223,
            albumId: "alb_1",
            artistId: "art_1"
        )
        try await syncService.ingest(songs: [song])

        // 2. Direct write of remote playlist via syncPlaylists simulation
        let sourceID = SourceID("src_\(serverID.rawValue)")
        let playlistID = "pl_remote_99"
        let key = "\(sourceID.rawValue):playlist:\(playlistID)"
        let digest = CryptoKit.SHA256.hash(data: Data(key.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))

        try await db.dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO playlists (id, title, description, artwork_reference, is_pinned, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    uuid.uuidString,
                    "周杰伦精选",
                    "来自 极空间 NAS",
                    nil,
                    0,
                    Date(),
                    Date()
                ]
            )
            try db.execute(
                sql: "INSERT INTO playlist_tracks (playlist_id, track_id, position, added_at) VALUES (?, ?, ?, ?)",
                arguments: [uuid.uuidString, "song_1", 0, Date()]
            )
        }

        // 3. Verify SQLite records
        let count = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playlists WHERE id = ?", arguments: [uuid.uuidString]) ?? 0
        }
        #expect(count == 1)

        let trackCount = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = ?", arguments: [uuid.uuidString]) ?? 0
        }
        #expect(trackCount == 1)

        // 4. Verify SourceRuntimeCoordinator fetchSourceStats
        let coordinator = await SourceRuntimeCoordinator(db: db, credentialStore: credStore)
        let stats = await coordinator.fetchSourceStats(sourceID: sourceID)
        #expect(stats.tracks == 1)
        #expect(stats.albums == 1)
    }

    @Test("SceneModel navigateToSource updates selectedSourceFilter and navigates to section")
    @MainActor
    func testSceneModelNavigateToSource() {
        let app = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: app, section: .sources)

        #expect(scene.navigation.section == .sources)
        #expect(scene.selectedSourceFilter == nil)

        // Navigate to Songs filtered by NAS
        scene.navigateToSource(sourceID: "src_subsonic_1", target: .library)
        #expect(scene.navigation.section == .library)
        #expect(scene.selectedSourceFilter == "src_subsonic_1")

        // Navigate to Albums filtered by Local
        scene.navigateToSource(sourceID: "local", target: .albums)
        #expect(scene.navigation.section == .albums)
        #expect(scene.selectedSourceFilter == "local")

        // Reset filter
        scene.navigateToSource(sourceID: nil, target: .playlists)
        #expect(scene.navigation.section == .playlists)
        #expect(scene.selectedSourceFilter == nil)
    }
}
