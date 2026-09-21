//
//  MetadataClaim.swift
//  MSRU
//
//  Observations and claims produced by readers. Decoupled from canonical data.
//

import Foundation

nonisolated public struct MetadataClaim: Identifiable, Hashable, Codable, Sendable {
    public let id: ClaimID
    public let assetID: AssetID
    public let field: String
    public let rawValue: String
    public let sourceReader: String
    public let confidence: Double
    public let observedAt: Date

    nonisolated public init(
        id: ClaimID = .generate(),
        assetID: AssetID,
        field: String,
        rawValue: String,
        sourceReader: String,
        confidence: Double,
        observedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.field = field
        self.rawValue = rawValue
        self.sourceReader = sourceReader
        self.confidence = max(0.0, min(1.0, confidence))
        self.observedAt = observedAt
    }
}

nonisolated public struct UserMetadataOverride: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let entityType: String // "recording", "release", "artist"
    public let entityID: String
    public let field: String
    public var overrideValue: String
    public var updatedAt: Date

    nonisolated public init(
        entityType: String,
        entityID: String,
        field: String,
        overrideValue: String,
        updatedAt: Date = Date()
    ) {
        self.id = "\(entityType):\(entityID):\(field)"
        self.entityType = entityType
        self.entityID = entityID
        self.field = field
        self.overrideValue = overrideValue
        self.updatedAt = updatedAt
    }
}
