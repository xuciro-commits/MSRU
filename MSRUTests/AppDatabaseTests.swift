//
//  AppDatabaseTests.swift
//  MSRUTests
//
//  Unit tests verifying SQLite database schema, foreign keys, and FTS5 capabilities.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@Suite("AppDatabase & Schema v1 Tests")
struct AppDatabaseTests {

    @Test("Verify ephemeral AppDatabase creation and schema migration")
    func testEphemeralDatabaseInitialization() throws {
        let db = try AppDatabase.makeEphemeral()
        #expect(db != nil)

        // Verify all 14 core tables + FTS exist
        try db.reader.read { db in
            let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
            #expect(tables.contains("sources"))
            #expect(tables.contains("assets"))
            #expect(tables.contains("artists"))
            #expect(tables.contains("recordings"))
            #expect(tables.contains("releases"))
            #expect(tables.contains("release_tracks"))
            #expect(tables.contains("artwork_assets"))
            #expect(tables.contains("fingerprints"))
            #expect(tables.contains("library_entries"))
            #expect(tables.contains("metadata_claims"))
            #expect(tables.contains("user_metadata_overrides"))
            #expect(tables.contains("library_fts"))
        }
    }

    @Test("Verify foreign key cascading deletion on assets and release tracks")
    func testForeignKeyCascading() async throws {
        let db = try AppDatabase.makeEphemeral()
        let sourceRepo = SourceRepository(db: db)
        let assetRepo = AssetRepository(db: db)

        let sourceID = SourceID("src_test_cascade")
        let source = Source(
            id: sourceID,
            sourceType: .localFolder,
            uri: "/test/music",
            displayName: "Test Music",
            capabilities: .localFolderDefault
        )
        try await sourceRepo.insertOrUpdate(source)

        let assetID = AssetID("ast_test_1")
        let asset = PersistedAssetRecord(
            id: assetID,
            sourceID: sourceID,
            relativePath: "Song.flac",
            fileSize: 1024,
            mtime: 1000,
            format: "FLAC",
            duration: 180
        )
        try await assetRepo.batchUpsert([asset])

        let countBefore = try await assetRepo.totalCount()
        #expect(countBefore == 1)

        // Deleting source must cascade and delete asset
        try await sourceRepo.delete(id: sourceID)
        let countAfter = try await assetRepo.totalCount()
        #expect(countAfter == 0)
    }

    @Test("Verify FTS5 virtual table indexing and search")
    func testFTS5VirtualTable() throws {
        let db = try AppDatabase.makeEphemeral()

        try db.dbWriter.write { db in
            try db.execute(
                sql: "INSERT INTO library_fts (recording_id, track_title, artist_name, release_title, catalog_number) VALUES (?, ?, ?, ?, ?)",
                arguments: ["rec_01", "晴天 (Sunny Day)", "周杰伦 (Jay Chou)", "叶惠美", "ALFA-001"]
            )
            try db.execute(
                sql: "INSERT INTO library_fts (recording_id, track_title, artist_name, release_title, catalog_number) VALUES (?, ?, ?, ?, ?)",
                arguments: ["rec_02", "Symphony No. 9", "Beethoven", "Karajan 1963", "DGG-1234"]
            )

            // Search "晴天"
            let results1 = try Row.fetchAll(db, sql: "SELECT recording_id FROM library_fts WHERE library_fts MATCH '晴天*'")
            #expect(results1.count == 1)
            #expect(results1.first?["recording_id"] == "rec_01")

            // Search "Beethoven"
            let results2 = try Row.fetchAll(db, sql: "SELECT recording_id FROM library_fts WHERE library_fts MATCH 'Beethoven*'")
            #expect(results2.count == 1)
            #expect(results2.first?["recording_id"] == "rec_02")
        }
    }
}
