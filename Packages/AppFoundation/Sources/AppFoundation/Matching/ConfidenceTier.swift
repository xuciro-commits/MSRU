//
//  ConfidenceTier.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation

/// Three-tier decision funnel for matching confidence (aligned with beets & IRE architecture spec).
public enum ConfidenceTier: String, Sendable, Codable, Equatable, Hashable, Comparable, CaseIterable {

    /// Unidentified or match distance too high (< 0.60). Preserves raw metadata without auto-linking.
    case low

    /// Medium confidence (0.60 ..< 0.90). Queued to Import Review workspace for user decision.
    case medium

    /// High confidence (>= 0.90). Automatic canonical resolution and entity association.
    case high

    /// Convenience checks
    public var isHighConfidence: Bool { self == .high }
    public var requiresReview: Bool { self == .medium }
    public var isUnidentified: Bool { self == .low }

    public static func < (lhs: ConfidenceTier, rhs: ConfidenceTier) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    /// Evaluates the appropriate confidence tier given a normalized score `[0.0, 1.0]`.
    public static func tier(
        for confidence: Double,
        highThreshold: Double = 0.90,
        mediumThreshold: Double = 0.60
    ) -> ConfidenceTier {
        if confidence >= highThreshold {
            return .high
        } else if confidence >= mediumThreshold {
            return .medium
        } else {
            return .low
        }
    }

    /// Convenience initializer mapping normalized confidence score to tier.
    public init(confidence: Double) {
        self = Self.tier(for: confidence)
    }
}
