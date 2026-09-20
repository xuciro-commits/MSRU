//
//  WeightedScoreModel.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation

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
        totalWeight: Double
    ) {
        self.confidence = confidence
        self.tier = tier
        self.components = components
        self.totalWeight = totalWeight
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
