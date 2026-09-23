//
//  StringDistanceTests.swift
//  AppFoundationTests
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import Testing
@testable import MusicDomain

struct StringDistanceTests {

    @Test
    func normalizeCleansPunctuationDiacriticsAndSpacing() {
        let raw = "  04.  晴天 (Jay Chou) -- [Original]! "
        let normalized = StringDistance.normalize(raw)
        #expect(normalized == "04 晴天 jay chou original")

        let accented = "Café au Lait"
        #expect(StringDistance.normalize(accented) == "cafe au lait")
    }

    @Test
    func levenshteinDistanceAndSimilarity() {
        // Exact match
        #expect(StringDistance.levenshteinDistance("晴天", "晴天") == 0)
        #expect(StringDistance.levenshteinSimilarity("晴天", "晴天") == 1.0)

        // Single character edit
        #expect(StringDistance.levenshteinDistance("晴天", "阴天") == 1)
        #expect(StringDistance.levenshteinSimilarity("晴天", "阴天") == 0.5)

        // Completely different
        #expect(StringDistance.levenshteinDistance("abc", "xyz") == 3)
        #expect(StringDistance.levenshteinSimilarity("abc", "xyz") == 0.0)
    }

    @Test
    func tokenJaccardSimilarityHandlesWordOrderVariations() {
        // Reordered tokens
        let sim1 = StringDistance.tokenJaccardSimilarity("Jay Chou", "Chou Jay")
        #expect(sim1 == 1.0)

        // Partial overlap
        let sim2 = StringDistance.tokenJaccardSimilarity("Jay Chou feat Gary", "Jay Chou")
        #expect(sim2 == 0.5) // 2 / 4
    }

    @Test
    func compositeSimilarityEvaluatesRealisticTitles() {
        // Near-identical with slight formatting variation
        let score = StringDistance.similarity("晴天 (Live at Taipei)", "晴天 Live at Taipei")
        #expect(score > 0.90)

        // Completely unrelated
        let badScore = StringDistance.similarity("晴天", "夜曲")
        #expect(badScore < 0.20)
    }

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
            WeightedComponent(name: "id_match", weight: 5.0, similarity: 1.0),
            WeightedComponent(name: "title_match", weight: 3.0, similarity: 0.90),
            WeightedComponent(name: "duration_match", weight: 2.0, similarity: 0.80),
            WeightedComponent(name: "year_match", weight: 1.0, similarity: 1.0)
        ]

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
            WeightedComponent(name: "id_match", weight: 5.0, similarity: 0.0),
            WeightedComponent(name: "title_match", weight: 3.0, similarity: 1.0),
            WeightedComponent(name: "artist_match", weight: 3.0, similarity: 0.9),
            WeightedComponent(name: "duration_match", weight: 2.0, similarity: 1.0)
        ]
        let result = WeightedScoreCalculator.calculate(components: components)
        #expect(result.tier == .low)
    }
}
