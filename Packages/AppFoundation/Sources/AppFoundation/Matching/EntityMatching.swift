//
//  EntityMatching.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation

// MARK: - Confidence Tier

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

// MARK: - String Distance

/// String similarity and fuzzy matching metrics for entity resolution and deduplication.
public enum StringDistance {

    /// Normalizes text by lowercasing, folding diacritics, removing punctuation, and collapsing whitespace.
    public static func normalize(_ string: String?) -> String {
        guard let string, !string.isEmpty else { return "" }
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = folded.unicodeScalars.filter { allowed.contains($0) }
        let trimmed = String(cleaned).components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return trimmed
    }

    /// Computes classic Levenshtein edit distance between two strings.
    public static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = min(prev[j], curr[j - 1], prev[j - 1]) + 1
                }
            }
            prev = curr
        }

        return prev[n]
    }

    /// Computes normalized Levenshtein similarity within range `[0.0, 1.0]`.
    public static func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        let maxLen = max(s1.count, s2.count)
        guard maxLen > 0 else { return 1.0 }
        let dist = levenshteinDistance(s1, s2)
        return max(0.0, 1.0 - (Double(dist) / Double(maxLen)))
    }

    /// Computes token-level Jaccard similarity (word-order invariant).
    public static func tokenJaccardSimilarity(_ s1: String, _ s2: String) -> Double {
        let tokens1 = Set(s1.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let tokens2 = Set(s2.components(separatedBy: .whitespaces).filter { !$0.isEmpty })

        if tokens1.isEmpty && tokens2.isEmpty { return 1.0 }
        if tokens1.isEmpty || tokens2.isEmpty { return 0.0 }

        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)

        return Double(intersection.count) / Double(union.count)
    }

    /// Computes a composite normalized similarity score combining token-based and Levenshtein metrics.
    public static func similarity(_ s1: String?, _ s2: String?) -> Double {
        let norm1 = normalize(s1)
        let norm2 = normalize(s2)

        if norm1.isEmpty && norm2.isEmpty { return 1.0 }
        if norm1.isEmpty || norm2.isEmpty { return 0.0 }
        if norm1 == norm2 { return 1.0 }

        let lev = levenshteinSimilarity(norm1, norm2)
        let jaccard = tokenJaccardSimilarity(norm1, norm2)

        // Give weight to both character edit distance and token reordering
        return (lev * 0.6) + (jaccard * 0.4)
    }
}

// MARK: - Entity Cluster

/// A generic cluster grouping related entities sharing a common structural or contextual signature.
public struct EntityCluster<Item: Identifiable & Sendable & Equatable>: Identifiable, Sendable, Equatable, Codable where Item: Codable, Item.ID: Codable & Sendable {

    /// Unique identifier for this cluster.
    public let id: String

    /// Optional semantic label (e.g. folder name, album candidate title).
    public var label: String?

    /// Constituent items belonging to this cluster.
    public var items: [Item]

    /// Key-value contextual metadata describing the cluster attributes.
    public var metadata: [String: String]

    public var count: Int {
        items.count
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public init(
        id: String = UUID().uuidString,
        label: String? = nil,
        items: [Item] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.label = label
        self.items = items
        self.metadata = metadata
    }

    /// Appends an item to this cluster.
    public mutating func append(_ item: Item) {
        items.append(item)
    }
}

// MARK: - Weighted Score Model

/// An individual weighted dimension within composite entity matching.
public struct WeightedComponent: Sendable, Equatable, Hashable, Codable {

    /// Name or descriptor of the evaluated dimension (e.g. "title", "mbid", "duration").
    public let name: String

    /// Relative weight factor for this dimension.
    public let weight: Double

    /// Normalized similarity score within range `[0.0, 1.0]`.
    public let similarity: Double

    public init(name: String, weight: Double, similarity: Double) {
        self.name = name
        self.weight = weight
        self.similarity = min(1.0, max(0.0, similarity))
    }

    /// Weighted contribution score.
    public var contribution: Double {
        weight * similarity
    }
}

/// The composite output of a multi-criteria weighted distance calculation.
public struct WeightedScoreResult: Sendable, Equatable, Hashable, Codable {

    /// Final composite confidence within `[0.0, 1.0]`.
    public let confidence: Double

    /// Funnel classification based on threshold rules.
    public let tier: ConfidenceTier

    /// Breakdown of individual component evaluations.
    public let components: [WeightedComponent]

    /// Sum of all evaluated component weights.
    public let totalWeight: Double

    public init(
        confidence: Double,
        tier: ConfidenceTier,
        components: [WeightedComponent],
        totalWeight: Double? = nil
    ) {
        self.confidence = confidence
        self.tier = tier
        self.components = components
        self.totalWeight = totalWeight ?? components.reduce(0.0) { $0 + $1.weight }
    }
}

/// Generic weighted distance engine implementing:
///
/// $$\text{Confidence} = \frac{\sum_{i} w_i \cdot s_i}{\sum_{i} w_i}$$
public enum WeightedScoreCalculator {

    /// Calculates composite confidence score and assigns appropriate confidence tier.
    public static func calculate(
        components: [WeightedComponent],
        highThreshold: Double = 0.90,
        mediumThreshold: Double = 0.60
    ) -> WeightedScoreResult {
        let totalWeight = components.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return WeightedScoreResult(
                confidence: 0.0,
                tier: .low,
                components: components,
                totalWeight: 0.0
            )
        }

        let totalContribution = components.reduce(0.0) { $0 + $1.contribution }
        let confidence = min(1.0, max(0.0, totalContribution / totalWeight))
        let tier = ConfidenceTier.tier(
            for: confidence,
            highThreshold: highThreshold,
            mediumThreshold: mediumThreshold
        )

        return WeightedScoreResult(
            confidence: confidence,
            tier: tier,
            components: components,
            totalWeight: totalWeight
        )
    }
}
