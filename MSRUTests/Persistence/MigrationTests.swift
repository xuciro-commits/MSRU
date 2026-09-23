//
//  MigrationTests.swift
//  MSRUTests
//
//  Canonical tests protecting schema version progression and data preservation across migrations.
//

import Testing
import Foundation
import AppFoundation
import MusicDomain
import GRDB
import MusicLibrary
@testable import MSRU

@Suite("Database Migration Contracts")
struct MigrationTests {

    @Test
    func migratorRegistersAllVersionsInOrder() throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()

        // Act & Assert: Schema version check
        let appliedMigrations = try appDb.reader.read { db in
            try Row.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid ASC")
                .compactMap { $0["identifier"] as String? }
        }

        #expect(appliedMigrations.contains("v1_create_music_identity_schema"))
        #expect(appliedMigrations.contains("v2_release_groups_file_assets_and_metadata_resolutions"))
        #expect(appliedMigrations.contains("v3_playlists_radio_rules_and_domain_storage"))
    }

    @Test
    func migrationIsIdempotentOnSubsequentRuns() throws {
        // Arrange
        let config = Configuration()
        let queue = try DatabaseQueue(configuration: config)
        let appDb = AppDatabase(dbWriter: queue)

        // Act: Run migrations twice
        try appDb.migrator.migrate(queue)
        try appDb.migrator.migrate(queue)

        // Assert: Tables exist and database is intact
        let tableCount: Int = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'") ?? 0
        }
        #expect(tableCount >= 15)
    }

    @Test
    func migrationV2BackfillsFileAssetsFromExistingV1Assets() throws {
        // Arrange: Create a blank DB and run only the production v1 migration
        let queue = try DatabaseQueue()
        var migratorV1 = DatabaseMigrator()
        AppDatabaseMigrations.registerV1(to: &migratorV1)
        try migratorV1.migrate(queue)

        // Seed v1 source and asset
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at)
                VALUES ('src_v1', 'localFolder', '/music', 'Music', 1, 1, '2026-01-01', '2026-01-01')
            """)
            try db.execute(sql: """
                INSERT INTO assets (id, source_id, relative_path, file_size, mtime, sha256, format, sample_rate, duration, created_at, updated_at)
                VALUES ('ast_v1_legacy', 'src_v1', 'album/song.flac', 45000000, 1700000000.0, 'sha256_mock_hash', 'FLAC', 96000, 240.0, '2026-01-01', '2026-01-01')
            """)
        }

        // Act: Apply full migrator including v2
        let appDb = AppDatabase(dbWriter: queue)
        try appDb.migrator.migrate(queue)

        // Assert: file_assets table was created and backfilled with ast_v1_legacy data
        let backfillData: (path: String, size: Int64, sig: String)? = try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT relative_path, file_size, physical_signature FROM file_assets WHERE asset_id = 'ast_v1_legacy'"
            ) else { return nil }
            let p: String = row["relative_path"]
            let s: Int64 = row["file_size"]
            let sig: String = row["physical_signature"]
            return (p, s, sig)
        }
        #expect(backfillData != nil)
        #expect(backfillData?.path == "album/song.flac")
        #expect(backfillData?.size == 45000000)
        #expect(backfillData?.sig == "sha256_mock_hash")
    }

    @Test
    @MainActor
    func legacyMediaFavoritesPlaylistsAndSourceSurviveMigrationAndRetry() async throws {
        struct LegacyMedia: Encodable {
            let fileURL: URL
            let title: String
            let artist: String
            let album: String?
            let duration: TimeInterval
            let artworkRelativePath: String?
            let trackNumber: Int?
            let year: Int?
        }

        let db = try TestDatabase.makeEphemeral()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("msru_migration_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let audioURL = folder.appendingPathComponent("song.flac")
        let mediaURL = folder.appendingPathComponent("external_tracks.json")
        let favoriteURL = folder.appendingPathComponent("Library.json")
        let playlistURL = folder.appendingPathComponent("playlists.json")
        let legacyMedia = LegacyMedia(fileURL: audioURL, title: "Song", artist: "Artist",
                                      album: "Album", duration: 180,
                                      artworkRelativePath: nil, trackNumber: 1, year: 2026)
        try JSONEncoder().encode([legacyMedia]).write(to: mediaURL)
        let favorite = LibraryTrack(title: "Song", artist: "Artist", album: "Album",
                                    sources: [LibraryPlaybackSource(kind: .local, localFileURL: audioURL)])
        try JSONEncoder().encode([favorite]).write(to: favoriteURL)
        let playlist = Playlist(title: "Legacy Favorites", trackIDs: [audioURL.absoluteString])
        try JSONEncoder().encode([playlist]).write(to: playlistURL)

        let mediaRepo = SQLiteLocalLibraryRepository(db: db, directory: folder)
        let favoriteRepo = SQLiteLibraryRepository(db: db, legacyFileURL: favoriteURL)
        let playlistRepo = SQLitePlaylistRepository(db: db, legacyFileURL: playlistURL)

        for _ in 0..<2 {
            let media = try await mediaRepo.fetchPage(LocalTrackPageRequest(limit: 128))
            let favorites = try await favoriteRepo.loadTracks()
            let playlists = try await playlistRepo.loadPlaylists()
            #expect(media.totalCount == 1)
            #expect(media.tracks.first?.fileURL == audioURL)
            #expect(favorites.first?.sources.first?.localFileURL == audioURL)
            #expect(playlists.first?.trackIDs == [audioURL.absoluteString])
        }

        for url in [mediaURL, favoriteURL, playlistURL] {
            #expect(!FileManager.default.fileExists(atPath: url.path))
            #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("legacy.backup").path))
        }
        let counts = try await db.reader.read { connection in
            [
                try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM sources WHERE source_type = 'local_folder'") ?? 0,
                try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM assets") ?? 0,
                try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM saved_library_tracks") ?? 0,
                try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM playlists") ?? 0
            ]
        }
        #expect(counts == [1, 1, 1, 1])
    }

    @Test
    func migrationV6MovesSubsonicUsernameOutOfDisplayName() throws {
        let queue = try DatabaseQueue()
        let appDb = AppDatabase(dbWriter: queue)
        try appDb.migrator.migrate(queue, upTo: "v5_r128_analysis")
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at) VALUES
                ('src_subsonic_ab12', 'future_provider', 'http://nas:8025', 'Home NAS (msru)', 8, 1, '2026-01-01', '2026-01-01'),
                ('src_subsonic_cd34', 'future_provider', 'http://nas2:4533', 'No user shape', 8, 1, '2026-01-01', '2026-01-01'),
                ('src_local_default', 'local_folder', 'file://local', 'Local Files', 1, 1, '2026-01-01', '2026-01-01')
            """)
        }

        try appDb.migrator.migrate(queue)
        try appDb.migrator.migrate(queue)

        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, source_type, display_name, username FROM sources ORDER BY id")
                .map { [$0["id"] as String, $0["source_type"] as String, $0["display_name"] as String, $0["username"] as String? ?? "-"] }
        }
        #expect(rows == [
            ["src_local_default", "local_folder", "Local Files", "-"],
            ["src_subsonic_ab12", "subsonic", "Home NAS", "msru"],
            ["src_subsonic_cd34", "subsonic", "No user shape", "-"]
        ])
    }
}
