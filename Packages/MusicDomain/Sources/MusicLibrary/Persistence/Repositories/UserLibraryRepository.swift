//
//  UserLibraryRepository.swift
//  MSRU
//
//  Repository managing user library state (favorites, ratings, play count, additions).
//

import Foundation
import AppFoundation
import GRDB
import MusicDomain

nonisolated public final class UserLibraryRepository: Sendable {
    private let db: AppDatabase

    nonisolated public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    public func setFavorite(recordingID: RecordingID, isFavorite: Bool) async throws {
        try await db.dbWriter.write { db in
            try db.execute(
                sql: """
                UPDATE library_entries SET is_favorite = ? WHERE recording_id = ?
                """,
                arguments: [isFavorite ? 1 : 0, recordingID.rawValue]
            )
        }
    }

    public func addLibraryEntry(
        id: LibraryEntryID = .generate(),
        recordingID: RecordingID,
        releaseTrackID: ReleaseTrackID? = nil,
        isFavorite: Bool = false,
        dateAdded: Date = Date()
    ) async throws {
        try await db.dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO library_entries (id, recording_id, release_track_id, is_favorite, rating, play_count, date_added)
                VALUES (?, ?, ?, ?, 0, 0, ?)
                ON CONFLICT(id) DO UPDATE SET
                    is_favorite = excluded.is_favorite
                """,
                arguments: [id.rawValue, recordingID.rawValue, releaseTrackID?.rawValue, isFavorite ? 1 : 0, dateAdded]
            )
        }
    }

    public func batchAddLibraryEntries(_ entries: [(recordingID: RecordingID, releaseTrackID: ReleaseTrackID?, isFavorite: Bool)]) async throws {
        try await db.dbWriter.write { db in
            let date = Date()
            for entry in entries {
                let id = LibraryEntryID.generate()
                try db.execute(
                    sql: """
                    INSERT INTO library_entries (id, recording_id, release_track_id, is_favorite, rating, play_count, date_added)
                    VALUES (?, ?, ?, ?, 0, 0, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        is_favorite = excluded.is_favorite
                    """,
                    arguments: [id.rawValue, entry.recordingID.rawValue, entry.releaseTrackID?.rawValue, entry.isFavorite ? 1 : 0, date]
                )
            }
        }
    }

    public func isFavorite(recordingID: RecordingID) async throws -> Bool {
        try await db.reader.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM library_entries WHERE recording_id = ? AND is_favorite = 1",
                arguments: [recordingID.rawValue]
            ) ?? 0
            return count > 0
        }
    }

    public func totalEntriesCount() async throws -> Int {
        try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM library_entries") ?? 0
        }
    }

    public func recordPlayback(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkReference: String? = nil,
        fileURL: URL? = nil
    ) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Artist" : artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        try await db.dbWriter.write { db in
            let now = Date()

            // 0. Check if existing recording exists from assets (if fileURL is provided)
            var matchedRecID: String?
            if let fileURL {
                let standardizedPath = fileURL.standardizedFileURL.path
                let row = try Row.fetchOne(
                    db,
                    sql: "SELECT recording_id FROM assets WHERE relative_path = ? OR relative_path = ?",
                    arguments: [standardizedPath, fileURL.path]
                )
                matchedRecID = row?["recording_id"]
            }

            let recID = matchedRecID.map { RecordingID($0) } ?? DeterministicID.recording(title: trimmedTitle, artist: trimmedArtist)

            // 1. Ensure Artist
            let artistID = DeterministicID.artist(name: trimmedArtist)
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO artists (id, name, sort_name, created_at)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [artistID.rawValue, trimmedArtist, trimmedArtist, now]
            )

            // 2. Ensure Recording
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO recordings (id, title, sort_title, duration, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [recID.rawValue, trimmedTitle, trimmedTitle, duration, now]
            )

            // 3. Ensure Artist Credit
            let creditID = UUID().uuidString
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO artist_credits (id, artist_id, entity_type, entity_id)
                VALUES (?, ?, 'recording', ?)
                """,
                arguments: [creditID, artistID.rawValue, recID.rawValue]
            )

            // 4. Ensure Release & Release Track if album provided
            if let album = album?.trimmingCharacters(in: .whitespacesAndNewlines), !album.isEmpty {
                let releaseID = DeterministicID.release(artist: trimmedArtist, title: album)
                try db.execute(
                    sql: """
                    INSERT OR IGNORE INTO releases (id, title, sort_title, artwork_asset_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [releaseID.rawValue, album, album, artworkReference, now]
                )

                let trackID = DeterministicID.releaseTrack(releaseID: releaseID, medium: 1, track: 1)
                try db.execute(
                    sql: """
                    INSERT OR IGNORE INTO release_tracks (id, release_id, medium_position, track_position, track_number, title, sort_title, duration, recording_id, created_at)
                    VALUES (?, ?, 1, 1, '1', ?, ?, ?, ?, ?)
                    """,
                    arguments: [trackID.rawValue, releaseID.rawValue, trimmedTitle, trimmedTitle, duration, recID.rawValue, now]
                )
            }

            // 5. If fileURL given and no asset exists yet, link asset to local source if available
            if let fileURL, matchedRecID == nil {
                var sourceID: String? = try Row.fetchOne(db, sql: "SELECT id FROM sources WHERE source_type = 'local' OR source_type = 'folder' LIMIT 1")?["id"]
                if sourceID == nil {
                    let defaultSourceID = "src_local_default"
                    try db.execute(
                        sql: """
                        INSERT OR IGNORE INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at)
                        VALUES (?, 'local', 'file:///', 'Local Library', 1, 1, ?, ?)
                        """,
                        arguments: [defaultSourceID, now, now]
                    )
                    sourceID = defaultSourceID
                }
                if let sourceID {
                    let astID = DeterministicID.asset(sourceID: SourceID(sourceID), relativePath: fileURL.path)
                    try db.execute(
                        sql: """
                        INSERT OR IGNORE INTO assets (id, source_id, relative_path, file_size, mtime, format, sample_rate, channels, duration, recording_id, created_at, updated_at)
                        VALUES (?, ?, ?, 0, ?, ?, 44100, 2, ?, ?, ?, ?)
                        """,
                        arguments: [astID.rawValue, sourceID, fileURL.path, now.timeIntervalSince1970, fileURL.pathExtension.uppercased(), duration, recID.rawValue, now, now]
                    )
                }
            }

            // 6. Upsert Library Entry with last_played_at and incremented play_count
            let existingEntry = try Row.fetchOne(
                db,
                sql: "SELECT id FROM library_entries WHERE recording_id = ?",
                arguments: [recID.rawValue]
            )

            if let existingEntry, let entryID: String = existingEntry["id"] {
                try db.execute(
                    sql: """
                    UPDATE library_entries
                    SET last_played_at = ?, play_count = play_count + 1
                    WHERE id = ?
                    """,
                    arguments: [now, entryID]
                )
            } else {
                let entryID = DeterministicID.libraryEntry(recordingID: recID)
                try db.execute(
                    sql: """
                    INSERT INTO library_entries (id, recording_id, is_favorite, rating, play_count, last_played_at, date_added)
                    VALUES (?, ?, 0, 0, 1, ?, ?)
                    """,
                    arguments: [entryID.rawValue, recID.rawValue, now, now]
                )
            }
        }
    }
}
