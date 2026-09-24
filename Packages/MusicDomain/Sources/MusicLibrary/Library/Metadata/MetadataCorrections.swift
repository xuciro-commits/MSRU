//
//  MetadataCorrections.swift
//  MSRU
//
//  User corrections of a recording's displayed metadata. Each correction is a
//  decision in the user decision log (principal, time, causation); the
//  `user_metadata_overrides` table is only the current-value projection.
//  File tags and the scanned values are never changed.
//

import Foundation
import GRDB
import MusicDomain

nonisolated public enum MetadataCorrections {
    public static let schema = DecisionSchema(name: "music.metadata-correction", version: 1)
    static let targetType = "recording"

    public enum Field: String, Codable, Sendable, CaseIterable {
        case title, artist, album
    }

    /// One entry of a recording's correction history; `value == nil` restores the scanned value.
    public struct Correction: Hashable, Sendable {
        public let field: Field
        public let value: String?
        public let principal: String
        public let recordedTime: Date

        nonisolated public init(field: Field, value: String?, principal: String, recordedTime: Date) {
            self.field = field
            self.value = value
            self.principal = principal
            self.recordedTime = recordedTime
        }
    }

    /// A recording's corrections, oldest first, and its revision: what a later
    /// correction names as seen, so one made from a stale screen is refused (K4 C12).
    public struct History: Hashable, Sendable {
        public let corrections: [Correction]
        public let revision: UInt32

        nonisolated public init(corrections: [Correction] = [], revision: UInt32 = 0) {
            self.corrections = corrections
            self.revision = revision
        }
    }

    struct Payload: Codable {
        let field: Field
        let value: String?
    }

    /// Records a correction and updates the projection in one transaction; returns the
    /// recording's new revision. `expectedRevision` is the revision the user saw.
    @discardableResult
    public static func correct(_ recordingID: RecordingID, field: Field, value: String?, expectedRevision: UInt32? = nil,
                               at now: Date = Date(), in db: Database) throws -> UInt32 {
        let target = DecisionTarget(type: targetType, id: recordingID.rawValue)
        let previous = try UserDecisionLog.records(tenant: UserDecisionLog.localTenant, target: target, in: db)
            .last { (try? JSONDecoder().decode(Payload.self, from: $0.submission.payload))?.field == field }
        var s = DecisionSubmission()
        s.tenantId = UserDecisionLog.localTenant
        s.principalId = UserDecisionLog.localPrincipal
        s.authority = UserDecisionLog.deviceAuthority
        s.target = target
        s.schema = schema
        s.causationId = previous?.changeId ?? ""
        s.idempotencyKey = UUID().uuidString
        s.payload = try JSONEncoder().encode(Payload(field: field, value: value))
        s.expectedRevision = expectedRevision
        let record = try UserDecisionLog.submit(s, knownSchemas: [schema], at: now, in: db)
        if let value {
            try db.execute(sql: """
                INSERT INTO user_metadata_overrides (id, entity_type, entity_id, field, override_value, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(entity_type, entity_id, field) DO UPDATE SET
                    override_value = excluded.override_value, updated_at = excluded.updated_at
                """, arguments: ["\(targetType):\(recordingID.rawValue):\(field.rawValue)", targetType,
                                 recordingID.rawValue, field.rawValue, value, now])
        } else {
            try db.execute(sql: "DELETE FROM user_metadata_overrides WHERE entity_type = ? AND entity_id = ? AND field = ?",
                           arguments: [targetType, recordingID.rawValue, field.rawValue])
        }
        return record.revision
    }

    /// All corrections of a recording, oldest first, with its revision.
    public static func history(_ recordingID: RecordingID, in db: Database) throws -> History {
        let records = try UserDecisionLog.records(tenant: UserDecisionLog.localTenant,
                                                  target: DecisionTarget(type: targetType, id: recordingID.rawValue), in: db)
        return History(corrections: records.compactMap { record in
                guard record.submission.schema == schema,
                      let payload = try? JSONDecoder().decode(Payload.self, from: record.submission.payload) else { return nil }
                return Correction(field: payload.field, value: payload.value,
                                  principal: record.submission.principalId, recordedTime: record.recordedTime)
        }, revision: records.last?.revision ?? 0)
    }

    /// SQL for a corrected column: the correction if any, otherwise `fallback`.
    static func corrected(_ field: Field, recordingColumn: String, fallback: String) -> String {
        """
        COALESCE((SELECT o.override_value FROM user_metadata_overrides o
                  WHERE o.entity_type = '\(targetType)' AND o.entity_id = \(recordingColumn)
                    AND o.field = '\(field.rawValue)'), \(fallback))
        """
    }
}
