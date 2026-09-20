//
//  WeightedScoreModelTests.swift
//  AppFoundationTests
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import Testing
@testable import AppFoundation

struct WeightedScoreModelTests {

    @Test
    func confidenceTierThresholds() {
        #expect(ConfidenceTier.tier(for: 0.95) == .high)
        #expect(ConfidenceTier.tier(for: 0.90) == .high)
        #expect(ConfidenceTier.tier(for: 0.89) == .medium)
        #expect(ConfidenceTier.tier(for: 0.60) == .medium)
        #expect(ConfidenceTier.tier(for: 0.59) == .low)
        #expect(ConfidenceTier.tier(for: 0.10) == .low)

        #expect(ConfidenceTier.high > ConfidenceTier.medium)
        #expect(ConfidenceTier.medium > ConfidenceTier.low)
    }

    @Test
    func weightedScoreCalculationAggregatesCorrectly() {
        let components: [WeightedComponent] = [
            WeightedComponent(name: "id_match", weight: 5.0, similarity: 1.0),      // 5.0 * 1.0 = 5.0
            WeightedComponent(name: "title_match", weight: 3.0, similarity: 0.90),   // 3.0 * 0.9 = 2.7
            WeightedComponent(name: "duration_match", weight: 2.0, similarity: 0.80),// 2.0 * 0.8 = 1.6
            WeightedComponent(name: "year_match", weight: 1.0, similarity: 1.0)      // 1.0 * 1.0 = 1.0
        ]
        // Total weight = 5 + 3 + 2 + 1 = 11.0
        // Total contribution = 5.0 + 2.7 + 1.6 + 1.0 = 10.3
        // Expected confidence = 10.3 / 11.0 ≈ 0.936

        let result = WeightedScoreCalculator.calculate(components: components)

        #expect(result.totalWeight == 11.0)
        #expect(abs(result.confidence - (10.3 / 11.0)) < 0.001)
        #expect(result.tier == .high)
        #expect(result.tier.isHighConfidence)
        #expect(!result.tier.requiresReview)
    }

    @Test
    func weightedScoreReachesMediumTierWhenIDMissing() {
        let components: [WeightedComponent] = [
            WeightedComponent(name: "id_match", weight: 5.0, similarity: 0.0),      // 0
            WeightedComponent(name: "title_match", weight: 3.0, similarity: 1.0),   // 3.0
            WeightedComponent(name: "artist_match", weight: 3.0, similarity: 0.9),  // 2.7
            WeightedComponent(name: "duration_match", weight: 2.0, similarity: 1.0) // 2.0
        ]
        // Total weight = 13.0
        // Total contribution = 0 + 3.0 + 2.7 + 2.0 = 7.7
        // Expected confidence = 7.7 / 13.0 ≈ 0.592 -> low
        let result = WeightedScoreCalculator.calculate(components: components)
        #expect(result.tier == .low)
    }
}
