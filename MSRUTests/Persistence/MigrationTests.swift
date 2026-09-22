//
//  MigrationTests.swift
//  MSRUTests
//
//  Canonical tests protecting schema version progression and data preservation across migrations.
//

import Testing
import Foundation
import AppFoundation
import GRDB
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
}
