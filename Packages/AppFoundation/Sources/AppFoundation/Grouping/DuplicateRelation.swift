//
//  DuplicateRelation.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation

/// Defines the structural relation between two entities during deduplication analysis.
public enum DuplicateRelationKind: String, Sendable, Codable, Equatable, Hashable, CaseIterable {

    /// Byte-for-byte or cryptographic digest exact duplicate.
    case exact

    /// Content/performance is identical but differs in wrapper, container, or non-essential encoding.
    case equivalent

    /// Represents an intentional or substantive variant (e.g. remastered edition, hi-res release).
    case variant

    /// The items are completely distinct and unrelated entities.
    case distinct
}

/// The result of comparing two entities for duplication or version relation.
public struct DuplicateResolution<ID: Hashable & Sendable & Codable>: Sendable, Codable, Equatable, Hashable {

    /// The categorized relationship between the compared items.
    public let kind: DuplicateRelationKind

    /// The recommended or preferred entity ID if one should take precedence.
    public let preferredID: ID?

    /// Mathematical confidence in this resolution (0.0 to 1.0).
    public let confidence: Double

    /// Explanatory diagnostic rationale.
    public let reason: String

    public init(
        kind: DuplicateRelationKind,
        preferredID: ID? = nil,
        confidence: Double = 1.0,
        reason: String = ""
    ) {
        self.kind = kind
        self.preferredID = preferredID
        self.confidence = confidence
        self.reason = reason
    }
}
