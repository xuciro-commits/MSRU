//
//  SourceRemovalTests.swift
//  MSRUTests
//

import Testing
import Foundation
import GRDB
import MusicLibrary
import SubsonicKit
@testable import MSRU

@Suite("Source removal keeps unrelated identity and user data")
@MainActor
struct SourceRemovalTests {
    private func seed(_ db: AppDatabase) async throws {
        try await db.dbWriter.write { db in
            let now = "2026-01-01"
            for (id, type) in [("src_subsonic_a", "subsonic"), ("src_local_default", "local_folder")] {
                try db.execute(sql: """
                    INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at)
                    VALUES (?, ?, 'x', ?, 0, 1, ?, ?)
                    """, arguments: [id, type, id, now, now])
            }
            // exclusive: only on the removed server; shared: on both; dormant: no asset at all.
            for id in ["rec_exclusive", "rec_shared", "rec_dormant"] {
                try db.execute(sql: "INSERT INTO recordings (id, title, sort_title, created_at) VALUES (?, ?, ?, ?)", arguments: [id, id, id, now])
            }
            for (id, title) in [("rel_remote", "Remote Album"), ("rel_dormant", "Dormant Album")] {
                try db.execute(sql: "INSERT INTO releases (id, title, sort_title, created_at) VALUES (?, ?, ?, ?)", arguments: [id, title, title, now])
            }
            for (id, release, recording, position) in [
                ("rt_1", "rel_remote", "rec_exclusive", 1),
                ("rt_2", "rel_dormant", "rec_dormant", 1)
            ] {
                try db.execute(sql: """
                    INSERT INTO release_tracks (id, release_id, track_position, track_number, title, sort_title, recording_id, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [id, release, position, "\(position)", id, id, recording, now])
            }
            for (id, name) in [("art_remote", "Remote Artist"), ("art_dormant", "Dormant Artist")] {
                try db.execute(sql: "INSERT INTO artists (id, name, sort_name, created_at) VALUES (?, ?, ?, ?)", arguments: [id, name, name, now])
            }
            for (id, artist, type, entity) in [
                ("ac_1", "art_remote", "recording", "rec_exclusive"),
                ("ac_2", "art_remote", "release", "rel_remote"),
                ("ac_3", "art_dormant", "recording", "rec_dormant")
            ] {
                try db.execute(sql: "INSERT INTO artist_credits (id, artist_id, entity_type, entity_id) VALUES (?, ?, ?, ?)", arguments: [id, artist, type, entity])
            }
            for (id, source, recording) in [
                ("ast_1", "src_subsonic_a", "rec_exclusive"),
                ("ast_2", "src_subsonic_a", "rec_shared"),
                ("ast_3", "src_local_default", "rec_shared")
            ] {
                try db.execute(sql: """
                    INSERT INTO assets (id, source_id, recording_id, relative_path, file_size, mtime, format, sample_rate, duration, created_at, updated_at)
                    VALUES (?, ?, ?, ?, 1, 0, 'FLAC', 44100, 1, ?, ?)
                    """, arguments: [id, source, recording, id, now, now])
            }
            for (id, recording) in [("le_1", "rec_dormant"), ("le_2", "rec_shared")] {
                try db.execute(sql: "INSERT INTO library_entries (id, recording_id, is_favorite, date_added) VALUES (?, ?, 1, ?)", arguments: [id, recording, now])
            }
        }
    }

    private func ids(_ table: String, _ db: AppDatabase) async throws -> [String] {
        try await db.reader.read { try String.fetchAll($0, sql: "SELECT id FROM \(table) ORDER BY id") }
    }

    private func makeCoordinator(_ db: AppDatabase) -> SourceRuntimeCoordinator {
        SourceRuntimeCoordinator(
            db: db,
            credentialStore: InMemorySubsonicCredentialStore(),
            legacyDefaults: UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        )
    }

    @Test("Opening sources never purges asset-less recordings or their favorites")
    func bootstrapKeepsDormantIdentity() async throws {
        let db = try AppDatabase.makeEphemeral()
        try await seed(db)
        try await db.dbWriter.write { try $0.execute(sql: "DELETE FROM sources WHERE id = 'src_subsonic_a'") }

        await makeCoordinator(db).bootstrapAll()

        #expect(try await ids("recordings", db) == ["rec_dormant", "rec_exclusive", "rec_shared"])
        #expect(try await ids("library_entries", db) == ["le_1", "le_2"])
        #expect(try await ids("artists", db) == ["art_dormant", "art_remote"])
    }

    @Test("Removing a source deletes only what that removal orphaned")
    func removalIsScoped() async throws {
        let db = try AppDatabase.makeEphemeral()
        try await seed(db)

        await makeCoordinator(db).removeSource(id: SourceID("src_subsonic_a"))

        #expect(try await ids("sources", db) == ["src_local_default"])
        #expect(try await ids("assets", db) == ["ast_3"])
        #expect(try await ids("recordings", db) == ["rec_dormant", "rec_shared"])
        #expect(try await ids("releases", db) == ["rel_dormant"])
        #expect(try await ids("artists", db) == ["art_dormant"])
        #expect(try await ids("artist_credits", db) == ["ac_3"])
        #expect(try await ids("library_entries", db) == ["le_1", "le_2"])
    }
}
