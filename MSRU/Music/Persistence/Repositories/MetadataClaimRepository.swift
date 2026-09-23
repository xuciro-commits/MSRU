//
//  MetadataClaimRepository.swift
//  MSRU
//
//  Repository managing raw observed metadata claims from different reader engines.
//

import Foundation
import AppFoundation
import GRDB

nonisolated public final class MetadataClaimRepository: Sendable {
    private let db: AppDatabase

    nonisolated public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    public func batchInsert(_ claims: [MetadataClaim]) async throws {
        guard !claims.isEmpty else { return }
        try await db.dbWriter.write { db in
            let statement = try db.makeStatement(sql: """
                INSERT INTO metadata_claims (id, asset_id, field, raw_value, source_reader, confidence, observed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """)
            for claim in claims {
                try statement.execute(arguments: [
                    claim.id.rawValue,
                    claim.assetID.rawValue,
                    claim.field,
                    claim.rawValue,
                    claim.sourceReader,
                    claim.confidence,
                    claim.observedAt
                ])
            }
        }
    }

    public func claims(for assetID: AssetID) async throws -> [MetadataClaim] {
        try await db.reader.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM metadata_claims WHERE asset_id = ? ORDER BY confidence DESC",
                arguments: [assetID.rawValue]
            )
            return rows.compactMap { row -> MetadataClaim? in
                guard let idStr: String = row["id"],
                      let assetIdStr: String = row["asset_id"],
                      let field: String = row["field"],
                      let rawValue: String = row["raw_value"],
                      let reader: String = row["source_reader"],
                      let confidence: Double = row["confidence"],
                      let observedAt: Date = row["observed_at"] else {
                    return nil
                }
                return MetadataClaim(
                    id: ClaimID(idStr),
                    assetID: AssetID(assetIdStr),
                    field: field,
                    rawValue: rawValue,
                    sourceReader: reader,
                    confidence: confidence,
                    observedAt: observedAt
                )
            }
        }
    }
}
