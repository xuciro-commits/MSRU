//
//  WebLibraryTests.swift
//  MSRUTests
//

import Testing
import Foundation
import GRDB
import MusicLibrary
@testable import MSRU

@Suite("Web tracks live in the library index")
@MainActor
struct WebLibraryTests {
    private let audio = OpenverseAudio(
        id: "ov-1", title: "Web Song", creator: "Web Artist",
        mediaURLString: "https://cdn.example/ov-1.mp3", durationMilliseconds: 90_000)

    @Test("Adding and removing a web track goes through the index")
    func addAndRemove() async throws {
        let db = try AppDatabase.makeEphemeral()
        let store = WebLibraryStore(db: db)

        await store.add(openverse: audio)
        #expect(store.contains(openverseID: "ov-1"))
        let track = try #require(store.tracks.first)
        #expect(track.title == "Web Song")
        #expect(track.artist == "Web Artist")
        #expect(track.fileURL.absoluteString == "https://cdn.example/ov-1.mp3")
        let favorite = try await db.reader.read {
            try Bool.fetchOne($0, sql: "SELECT is_favorite FROM library_entries LIMIT 1")
        }
        #expect(favorite == false)

        await store.add(openverse: audio)
        #expect(store.tracks.count == 1)

        await store.remove(trackIDs: [track.id])
        #expect(store.tracks.isEmpty)
        #expect(!store.contains(openverseID: "ov-1"))
        let recordings = try await db.reader.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM recordings") }
        #expect(recordings == 0)
    }

    @Test("Migration v7 moves saved web tracks into the index and ignores local markers")
    func savedWebTracksMigrate() async throws {
        let queue = try DatabaseQueue()
        let appDb = AppDatabase(dbWriter: queue)
        try appDb.migrator.migrate(queue, upTo: "v6_subsonic_sources")
        try await queue.write { db in
            try db.execute(sql: """
                INSERT INTO saved_library_tracks (id, title, artist, duration, date_added) VALUES
                ('t-web', 'Saved Web', 'Creator', 120, '2026-02-01 10:00:00'),
                ('t-local', 'Saved File', 'Artist', 200, '2026-02-02 10:00:00')
                """)
            try db.execute(sql: """
                INSERT INTO saved_library_sources (id, library_track_id, kind, local_url, remote_url, external_id) VALUES
                ('s-web', 't-web', 'openverse', NULL, 'https://cdn.example/saved.mp3', 'ov-saved'),
                ('s-local', 't-local', 'local', 'file:///music/a.flac', NULL, NULL)
                """)
        }

        try appDb.migrator.migrate(queue)

        let store = WebLibraryStore(db: appDb)
        await store.load()
        #expect(store.tracks.map(\.title) == ["Saved Web"])
        #expect(store.contains(openverseID: "ov-saved"))
        let favorites = try await queue.read { db in
            try Bool.fetchAll(db, sql: "SELECT is_favorite FROM library_entries")
        }
        #expect(favorites == [false])
        // Old tables stay untouched as a recovery path.
        let oldRows = try await queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM saved_library_tracks") }
        #expect(oldRows == 2)
    }
}
