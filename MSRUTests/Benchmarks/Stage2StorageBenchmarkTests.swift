import Foundation
import Darwin
import GRDB
import Testing
@testable import MSRU

/// Opt-in code-path benchmark. Run prepare, paged and legacy as separate test processes.
/// The synthetic fixture is kept outside the app's real data directory.
@Suite("Stage 2 disk storage benchmark", .enabled(if: FileManager.default.fileExists(atPath: "/tmp/msru-stage2-50k-benchmark-mode")))
struct Stage2StorageBenchmarkTests {
    private static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("msru-stage2-50k-benchmark", isDirectory: true)
    private static let databaseURL = directory.appendingPathComponent("library.sqlite")
    private static let modeURL = URL(fileURLWithPath: "/tmp/msru-stage2-50k-benchmark-mode")
    private static var mode: String? {
        try? String(contentsOf: modeURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("prepare fixed 50,000-song disk fixture")
    func prepare() throws {
        guard Self.mode == "prepare" else { return }
        try? FileManager.default.removeItem(at: Self.directory)
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let db = try AppDatabase(at: Self.databaseURL)
        try db.dbWriter.write { connection in
            try connection.execute(sql: """
                INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at)
                VALUES ('src_local_default', 'local_folder', '/music', 'Local', 1, 1, ?, ?)
                """, arguments: [Date(), Date()])
            for artist in 0..<100 {
                let id = String(format: "%03d", artist)
                try connection.execute(sql: "INSERT INTO artists (id, name, sort_name, created_at) VALUES (?, ?, ?, ?)",
                                       arguments: ["art_\(id)", "Artist \(id)", "artist \(id)", Date()])
            }
            for album in 0..<1_000 {
                let id = String(format: "%04d", album)
                let artistID = String(format: "%03d", album / 10)
                try connection.execute(sql: "INSERT INTO releases (id, title, sort_title, created_at) VALUES (?, ?, ?, ?)",
                                       arguments: ["rel_\(id)", "Album \(id)", "album \(id)", Date()])
                try connection.execute(sql: "INSERT INTO artist_credits (id, artist_id, entity_type, entity_id) VALUES (?, ?, 'release', ?)",
                                       arguments: ["credit_rel_\(id)", "art_\(artistID)", "rel_\(id)"])
            }
            for index in 0..<50_000 {
                let number = String(format: "%05d", index)
                let albumID = String(format: "%04d", index / 50)
                let artistID = String(format: "%03d", index / 500)
                try connection.execute(sql: "INSERT INTO recordings (id, title, sort_title, duration, created_at) VALUES (?, ?, ?, 180, ?)",
                                       arguments: ["rec_\(number)", "Song \(number)", "song \(number)", Date()])
                try connection.execute(sql: """
                    INSERT INTO assets (id, source_id, relative_path, file_size, mtime, format,
                                        sample_rate, duration, recording_id, created_at, updated_at)
                    VALUES (?, 'src_local_default', ?, 1000, 1, 'WAV', 48000, 180, ?, ?, ?)
                    """, arguments: ["ast_\(number)", "/music/\(number).wav", "rec_\(number)", Date(), Date()])
                try connection.execute(sql: """
                    INSERT INTO release_tracks (id, release_id, track_position, track_number,
                                                title, sort_title, recording_id, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: ["rt_\(number)", "rel_\(albumID)", index % 50 + 1,
                                    String(index % 50 + 1), "Song \(number)", "song \(number)",
                                    "rec_\(number)", Date()])
                try connection.execute(sql: "INSERT INTO artist_credits (id, artist_id, entity_type, entity_id) VALUES (?, ?, 'recording', ?)",
                                       arguments: ["credit_rec_\(number)", "art_\(artistID)", "rec_\(number)"])
            }
        }
        print("[Stage2StorageBenchmark] prepared songs=50000 albums=1000 artists=100 path=\(Self.databaseURL.path)")
    }

    @Test("measure bounded startup data path")
    @MainActor
    func paged() async throws {
        guard Self.mode == "paged" else { return }
        let rssBefore = residentBytes()
        let started = CFAbsoluteTimeGetCurrent()
        let db = try AppDatabase(at: Self.databaseURL)
        let store = LocalLibraryStore(repository: SQLiteLocalLibraryRepository(db: db), db: db)
        await store.loadIfNeeded()
        let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
        let rssAfter = residentBytes()
        #expect(store.totalTrackCount == 50_000)
        #expect(store.tracks.count == 128)
        print("[Stage2StorageBenchmark] mode=paged ms=\(String(format: "%.2f", elapsed)) rssBefore=\(rssBefore) rssAfter=\(rssAfter) rssDelta=\(rssAfter - rssBefore) residentTracks=\(store.tracks.count)")
    }

    @Test("measure previous full materialization path")
    @MainActor
    func legacy() async throws {
        guard Self.mode == "legacy" else { return }
        let rssBefore = residentBytes()
        let started = CFAbsoluteTimeGetCurrent()
        let db = try AppDatabase(at: Self.databaseURL)
        let tracks = try await SQLiteLocalLibraryRepository(db: db).loadTracks()
        let snapshot = try await LibraryQueryEngine(db: db).queryDatabaseSnapshot()
        let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
        let rssAfter = residentBytes()
        #expect(tracks.count == 50_000)
        #expect(snapshot.albumSummaries.count == 1_000)
        print("[Stage2StorageBenchmark] mode=legacy ms=\(String(format: "%.2f", elapsed)) rssBefore=\(rssBefore) rssAfter=\(rssAfter) rssDelta=\(rssAfter - rssBefore) residentTracks=\(tracks.count) summaryRows=\(snapshot.albumSummaries.count + snapshot.artistSummaries.count)")
    }

    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
}
