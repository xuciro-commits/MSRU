//
//  MatchScorerTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct MatchScorerTests {

    @Test
    func highConfidenceMatchWhenMBIDMatchesDirectly() {
        let query = MatchQuery(
            trackMBID: "rec_sunny_day_mbid",
            title: "04 晴天",
            artist: "Jay Chou",
            album: "叶惠美",
            duration: 269.0,
            trackNumber: 4,
            year: 2003
        )

        let candidate = CatalogTrackCandidate(
            trackMBID: "rec_sunny_day_mbid",
            releaseMBID: "rel_ye_hui_mei",
            title: "晴天",
            artist: "周杰伦",
            artistAliases: ["Jay Chou", "周杰倫"],
            album: "叶惠美",
            duration: 269.0,
            trackNumber: 4,
            year: 2003
        )

        let result = MatchScorer.evaluate(query: query, against: candidate)

        // With MBID (weight 5.0) matching perfectly, score should easily exceed 0.90
        #expect(result.confidence >= 0.90)
        #expect(result.tier == .high)
        #expect(result.tier.isHighConfidence)
        #expect(!result.tier.requiresReview)
    }

    @Test
    func mediumConfidenceReviewWhenFuzzyMatchedWithoutMBID() {
        // Query has no MBID, slightly different title spelling and small duration drift
        let query = MatchQuery(
            title: "晴天 (Live Taipei)",
            artist: "周杰伦",
            album: "叶惠美",
            duration: 272.0, // 3 seconds delta
            trackNumber: 4,
            year: 2003
        )

        let candidate = CatalogTrackCandidate(
            trackMBID: "rec_sunny_day_studio",
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            duration: 269.0,
            trackNumber: 4,
            year: 2003
        )

        let result = MatchScorer.evaluate(query: query, against: candidate)

        // Without MBID, title partial match, but artist/album/trackNumber match
        #expect(result.confidence >= 0.60)
        #expect(result.confidence < 0.90)
        #expect(result.tier == .medium)
        #expect(result.tier.requiresReview)
    }

    @Test
    func lowConfidenceRejectionForMismatchedSong() {
        let query = MatchQuery(
            title: "夜曲",
            artist: "周杰伦",
            duration: 226.0
        )

        let candidate = CatalogTrackCandidate(
            trackMBID: "rec_sunny_day",
            title: "晴天",
            artist: "周杰伦",
            duration: 269.0
        )

        let result = MatchScorer.evaluate(query: query, against: candidate)

        #expect(result.confidence < 0.60)
        #expect(result.tier == .low)
        #expect(result.tier.isUnidentified)
    }
}
