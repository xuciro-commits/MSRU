//
//  UserLibraryRepository.swift
//  MSRU
//
//  Repository managing user library state (favorites, ratings, play count, additions).
//

import Foundation
import AppFoundation

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

    public func setMetadataOverride(entityType: String, entityID: String, field: String, value: String) async throws {
        let overrideID = "\(entityType):\(entityID):\(field)"
        try await db.dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO user_metadata_overrides (id, entity_type, entity_id, field, override_value, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    override_value = excluded.override_value,
                    updated_at = excluded.updated_at
                """,
                arguments: [overrideID, entityType, entityID, field, value, Date()]
            )
        }
    }
}
