//
//  StringDistanceTests.swift
//  AppFoundationTests
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import Testing
@testable import AppFoundation

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
}
