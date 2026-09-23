import Foundation
import GRDB
import Testing
@testable import MSRU

@Suite("Local SQLite paging")
struct LocalPagingTests {
    @Test("50,000-row first page, deep page and search stay bounded")
    @MainActor
    func fiftyThousandRows() async throws {
        let db = try TestDatabase.makeEphemeral()
        try await db.dbWriter.write { connection in
            try connection.execute(sql: """
                INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at)
                VALUES ('src_local_default', 'local_folder', '/music', 'Local', 1, 1, ?, ?)
                """, arguments: [Date(), Date()])
            for index in 0..<50_000 {
                let number = String(format: "%05d", index)
                try connection.execute(sql: """
                    INSERT INTO recordings (id, title, sort_title, duration, created_at)
                    VALUES (?, ?, ?, 180, ?)
                    """, arguments: ["rec_\(number)", "Song \(number)", "song \(number)", Date()])
                try connection.execute(sql: """
                    INSERT INTO assets (id, source_id, relative_path, file_size, mtime, format,
                                        sample_rate, duration, recording_id, created_at, updated_at)
                    VALUES (?, 'src_local_default', ?, 1000, 1, 'WAV', 48000, 180, ?, ?, ?)
                    """, arguments: ["ast_\(number)", "/music/\(number).wav", "rec_\(number)", Date(), Date()])
            }
        }
        let repository = SQLiteLocalLibraryRepository(db: db)
        let store = LocalLibraryStore(repository: repository, db: db)
        let storeStarted = CFAbsoluteTimeGetCurrent()
        await store.loadIfNeeded()
        let boundedStoreMs = (CFAbsoluteTimeGetCurrent() - storeStarted) * 1000
        #expect(store.isLoaded)
        #expect(!store.isFullyLoaded)
        #expect(store.totalTrackCount == 50_000)
        #expect(store.tracks.count == 128)
        let fullLoadStarted = CFAbsoluteTimeGetCurrent()
        let full = try await repository.loadTracks()
        let fullLoadMs = (CFAbsoluteTimeGetCurrent() - fullLoadStarted) * 1000
        #expect(full.count == 50_000)
        let started = CFAbsoluteTimeGetCurrent()
        let first = try await repository.fetchPage(LocalTrackPageRequest(limit: 128))
        let firstMs = (CFAbsoluteTimeGetCurrent() - started) * 1000
        #expect(first.totalCount == 50_000)
        #expect(first.tracks.count == 128)
        #expect(first.hasMore)
        let snapshotStarted = CFAbsoluteTimeGetCurrent()
        let snapshot = await LibraryQueryEngine(db: db).querySnapshot()
        let snapshotMs = (CFAbsoluteTimeGetCurrent() - snapshotStarted) * 1000
        #expect(snapshot.count == 50_000)
        let deep = try await repository.fetchPage(LocalTrackPageRequest(offset: 49_920, limit: 128))
        #expect(deep.tracks.count == 80)
        #expect(!deep.hasMore)
        let search = try await repository.fetchPage(LocalTrackPageRequest(query: "0499", limit: 128))
        #expect(search.totalCount == 15)
        #expect(search.tracks.count == 15)
        let pager = LocalTrackPager(repository: repository)
        await pager.reset(query: "", sort: .title, ascending: true)
        #expect(pager.tracks.count == 128)
        await pager.loadMore()
        #expect(pager.tracks.count == 256)
        await pager.reset(query: "0499", sort: .title, ascending: true)
        #expect(pager.tracks.count == 15)
        #expect(!pager.hasMore)
        print("[LocalPagingBenchmark] dataset=50000 boundedStoreMs=\(String(format: "%.2f", boundedStoreMs)) residentRows=\(store.tracks.count) fullLoadMs=\(String(format: "%.2f", fullLoadMs)) fullRows=\(full.count) firstPageMs=\(String(format: "%.2f", firstMs)) pageRows=\(first.tracks.count) snapshotMs=\(String(format: "%.2f", snapshotMs))")

        let smart = Playlist(title: "One song", rules: SmartPlaylistRuleGroup(rules: [
            SmartPlaylistRule(field: .title, op: .equals, value: .string("Song 00001"))
        ]))
        let resolved = try await store.resolvePlaylistTracks(smart)
        #expect(resolved.map(\.title) == ["Song 00001"])
        #expect(!store.isFullyLoaded)

        let lastID = try #require(full.last?.id)
        #expect(await store.deleteTracks(withIDs: [lastID]))
        #expect(!store.isFullyLoaded)
        #expect(store.totalTrackCount == 49_999)
        #expect(store.tracks.count == 128)
        #expect(try await repository.fetchTracks(withIDs: [lastID]).isEmpty)
    }
}
