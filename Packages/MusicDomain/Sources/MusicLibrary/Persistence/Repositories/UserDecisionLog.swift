//
//  UserDecisionLog.swift
//  MSRU
//
//  User decisions as kernel change records (platform contract v1alpha1, K4):
//  principal, authority, causation and idempotency, in an append-only log.
//  The personal library is a degenerate tenant with device authority (K5, K6).
//

import Foundation
import GRDB

nonisolated public struct DecisionTarget: Hashable, Codable, Sendable {
    public var type: String
    public var id: String

    public init(type: String, id: String) {
        self.type = type
        self.id = id
    }
}

nonisolated public struct DecisionSchema: Hashable, Codable, Sendable {
    public var name: String
    public var version: UInt32

    public init(name: String, version: UInt32) {
        self.name = name
        self.version = version
    }
}

/// A decision as submitted; mirrors the contract's `Submission`.
nonisolated public struct DecisionSubmission: Hashable, Codable, Sendable {
    public var tenantId = ""
    public var principalId = ""
    public var authority = ""
    public var target = DecisionTarget(type: "", id: "")
    public var schema = DecisionSchema(name: "", version: 0)
    public var validTime: Date?
    public var causationId = ""
    public var correlationId = ""
    public var idempotencyKey = ""
    public var payload = Data()
    /// Facts (here: metadata claims) the decision is based on (C11).
    public var evidenceFactIds: [String] = []
    /// The target's revision the submitter saw; a different current revision is a conflict (C12).
    public var expectedRevision: UInt32?

    public init() {}

    // Proto3 JSON omits default values.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tenantId = try c.decodeIfPresent(String.self, forKey: .tenantId) ?? ""
        principalId = try c.decodeIfPresent(String.self, forKey: .principalId) ?? ""
        authority = try c.decodeIfPresent(String.self, forKey: .authority) ?? ""
        target = try c.decodeIfPresent(DecisionTarget.self, forKey: .target) ?? target
        schema = try c.decodeIfPresent(DecisionSchema.self, forKey: .schema) ?? schema
        validTime = try c.decodeIfPresent(Date.self, forKey: .validTime)
        causationId = try c.decodeIfPresent(String.self, forKey: .causationId) ?? ""
        correlationId = try c.decodeIfPresent(String.self, forKey: .correlationId) ?? ""
        idempotencyKey = try c.decodeIfPresent(String.self, forKey: .idempotencyKey) ?? ""
        payload = try c.decodeIfPresent(Data.self, forKey: .payload) ?? Data()
        evidenceFactIds = try c.decodeIfPresent([String].self, forKey: .evidenceFactIds) ?? []
        expectedRevision = try c.decodeIfPresent(UInt32.self, forKey: .expectedRevision)
    }
}

nonisolated public struct DecisionRecord: Hashable, Sendable {
    public let changeId: String
    public let submission: DecisionSubmission
    public let validTime: Date
    public let recordedTime: Date
    /// The target's revision after this decision: accepted decisions about it so far (C12).
    public let revision: UInt32
}

/// Contract error codes this log can return.
nonisolated public enum DecisionError: String, Error, Sendable {
    case invalidArgument = "ERROR_CODE_INVALID_ARGUMENT"
    case invalidReference = "ERROR_CODE_INVALID_REFERENCE"
    case idempotencyConflict = "ERROR_CODE_IDEMPOTENCY_CONFLICT"
    case unknownSchema = "ERROR_CODE_UNKNOWN_SCHEMA"
    case conflict = "ERROR_CODE_CONFLICT"
}

nonisolated public enum UserDecisionLog {
    /// The personal library: one tenant, one principal, this device as authority.
    public static let localTenant = "local"
    public static let localPrincipal = "local-owner"
    public static let deviceAuthority = "device"

    /// Accepts a submission or rejects it; a rejection writes nothing (C1–C12). `knownFact`
    /// overrides where evidence is looked up; by default the local tenant's metadata claims.
    @discardableResult
    public static func submit(_ s: DecisionSubmission, knownSchemas: Set<DecisionSchema>, at now: Date,
                              knownFact: ((_ tenant: String, _ factId: String) -> Bool)? = nil,
                              in db: Database) throws -> DecisionRecord {
        let required = [s.tenantId, s.principalId, s.authority, s.idempotencyKey, s.target.type, s.target.id, s.schema.name]
        guard !required.contains(where: \.isEmpty) else { throw DecisionError.invalidArgument }
        guard knownSchemas.contains(s.schema) else { throw DecisionError.unknownSchema }
        if let existing = try Row.fetchOne(db, sql: "SELECT * FROM user_decisions WHERE tenant_id = ? AND idempotency_key = ?",
                                           arguments: [s.tenantId, s.idempotencyKey]).map(record) {
            guard existing.submission == s else { throw DecisionError.idempotencyConflict }
            return existing
        }
        if !s.causationId.isEmpty, try Bool.fetchOne(db, sql: """
            SELECT NOT EXISTS (SELECT 1 FROM user_decisions WHERE tenant_id = ? AND change_id = ?)
            """, arguments: [s.tenantId, s.causationId]) == true {
            throw DecisionError.invalidReference
        }
        for fact in s.evidenceFactIds {
            let known = try knownFact?(s.tenantId, fact) ?? (s.tenantId == localTenant && Bool.fetchOne(db, sql:
                "SELECT EXISTS (SELECT 1 FROM metadata_claims WHERE id = ?)", arguments: [fact]) == true)
            guard known else { throw DecisionError.invalidReference }
        }
        let current = try UInt32.fetchOne(db, sql: """
            SELECT COUNT(*) FROM user_decisions WHERE tenant_id = ? AND target_type = ? AND target_id = ?
            """, arguments: [s.tenantId, s.target.type, s.target.id]) ?? 0
        if let expected = s.expectedRevision, expected != current { throw DecisionError.conflict }
        let last = try Date.fetchOne(db, sql: "SELECT MAX(recorded_time) FROM user_decisions WHERE tenant_id = ?",
                                     arguments: [s.tenantId])
        let recorded = max(now, last ?? now)
        let result = DecisionRecord(changeId: UUID().uuidString, submission: s,
                                    validTime: s.validTime ?? recorded, recordedTime: recorded, revision: current + 1)
        try db.execute(sql: """
            INSERT INTO user_decisions (change_id, tenant_id, principal_id, authority, target_type, target_id,
                schema_name, schema_version, valid_time, submitted_valid_time, recorded_time, causation_id,
                correlation_id, idempotency_key, payload, evidence_fact_ids, expected_revision, revision)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [result.changeId, s.tenantId, s.principalId, s.authority, s.target.type, s.target.id,
                             s.schema.name, s.schema.version, result.validTime, s.validTime, recorded, s.causationId,
                             s.correlationId, s.idempotencyKey, s.payload,
                             String(decoding: try JSONEncoder().encode(s.evidenceFactIds), as: UTF8.self),
                             s.expectedRevision, result.revision])
        return result
    }

    /// A tenant's log in recorded order; with `target`, only decisions about it.
    public static func records(tenant: String, target: DecisionTarget? = nil, in db: Database) throws -> [DecisionRecord] {
        let filter = target == nil ? "" : " AND target_type = ? AND target_id = ?"
        let arguments: StatementArguments = target.map { [tenant, $0.type, $0.id] } ?? [tenant]
        return try Row.fetchAll(db, sql: "SELECT * FROM user_decisions WHERE tenant_id = ?" + filter + " ORDER BY rowid",
                                arguments: arguments).map(record)
    }

    private static func record(_ row: Row) -> DecisionRecord {
        var s = DecisionSubmission()
        s.tenantId = row["tenant_id"]
        s.principalId = row["principal_id"]
        s.authority = row["authority"]
        s.target = DecisionTarget(type: row["target_type"], id: row["target_id"])
        s.schema = DecisionSchema(name: row["schema_name"], version: row["schema_version"])
        s.validTime = row["submitted_valid_time"]
        s.causationId = row["causation_id"]
        s.correlationId = row["correlation_id"]
        s.idempotencyKey = row["idempotency_key"]
        s.payload = row["payload"]
        s.evidenceFactIds = (try? JSONDecoder().decode([String].self, from: Data((row["evidence_fact_ids"] as String? ?? "[]").utf8))) ?? []
        s.expectedRevision = row["expected_revision"]
        return DecisionRecord(changeId: row["change_id"], submission: s, validTime: row["valid_time"],
                              recordedTime: row["recorded_time"], revision: row["revision"])
    }
}
