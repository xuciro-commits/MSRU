//
//  SourceRepository.swift
//  MSRU
//
//  Repository managing audio sources and capability storage.
//

import Foundation
import AppFoundation
import GRDB

nonisolated public final class SourceRepository: Sendable {
    private let db: AppDatabase

    nonisolated public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    public func insertOrUpdate(_ source: Source) async throws {
        try await db.dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, last_reconciled_at, bookmark_blob, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    source_type = excluded.source_type,
                    uri = excluded.uri,
                    display_name = excluded.display_name,
                    capabilities = excluded.capabilities,
                    is_enabled = excluded.is_enabled,
                    last_reconciled_at = excluded.last_reconciled_at,
                    bookmark_blob = excluded.bookmark_blob,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    source.id.rawValue,
                    source.sourceType.rawValue,
                    source.uri,
                    source.displayName,
                    source.capabilities.rawValue,
                    source.isEnabled ? 1 : 0,
                    source.lastReconciledAt,
                    source.bookmarkData,
                    source.createdAt,
                    source.updatedAt
                ]
            )
        }
    }

    public func loadAll() async throws -> [Source] {
        try await db.reader.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM sources ORDER BY display_name ASC")
            return rows.compactMap { row -> Source? in
                guard let idStr: String = row["id"],
                      let typeStr: String = row["source_type"],
                      let sourceType = SourceType(rawValue: typeStr),
                      let uri: String = row["uri"],
                      let displayName: String = row["display_name"],
                      let capsRaw: Int = row["capabilities"],
                      let createdAt: Date = row["created_at"],
                      let updatedAt: Date = row["updated_at"] else {
                    return nil
                }
                let isEnabled: Bool = (row["is_enabled"] as? Int ?? 1) == 1
                let lastReconciledAt: Date? = row["last_reconciled_at"]
                let bookmarkBlob: Data? = row["bookmark_blob"]

                return Source(
                    id: SourceID(idStr),
                    sourceType: sourceType,
                    uri: uri,
                    displayName: displayName,
                    capabilities: SourceCapabilities(rawValue: capsRaw),
                    isEnabled: isEnabled,
                    lastReconciledAt: lastReconciledAt,
                    bookmarkData: bookmarkBlob,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            }
        }
    }

    public func delete(id: SourceID) async throws {
        try await db.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM sources WHERE id = ?", arguments: [id.rawValue])
        }
    }
}
