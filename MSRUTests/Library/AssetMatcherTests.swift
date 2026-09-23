//
//  AssetMatcherTests.swift
//  MSRUTests
//
//  Evidence-based matching tests ensuring version consolidation invariants.
//  Strictly enforces that naive "same artist + same title" does NOT automatically merge.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
@Suite("Asset Matching & Evidence Invariants")
struct AssetMatcherTests {

    @Test("Exact audio PCM signature achieves high confidence")
    func exactAudioSignatureMatch() {
        let candA = AssetMatchCandidate(
            title: "Hotel California",
            artist: "Eagles",
            duration: 391.0,
            exactSignature: "pcm_sha256_abcdef1234567890"
        )
        let candB = AssetMatchCandidate(
            title: "Hotel California (2013 Remaster)",
            artist: "The Eagles",
            duration: 391.2,
            exactSignature: "pcm_sha256_abcdef1234567890"
        )

        let result = AssetMatcher.evaluate(source: candA, target: candB)
        #expect(result.score == 1.0)
        #expect(result.tier == .high)
        #expect(result.canFormVersion)
    }

    @Test("Matching MusicBrainz recording MBID achieves high confidence")
    func mbidMatch() {
        let mbid = "25c1103c-74a5-48b8-b2a6-0683ec8912df"
        let candA = AssetMatchCandidate(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            duration: 354.0,
            mbid: mbid
        )
        let candB = AssetMatchCandidate(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            duration: 355.0,
            mbid: mbid
        )

        let result = AssetMatcher.evaluate(source: candA, target: candB)
        #expect(result.score >= 0.95)
        #expect(result.tier == .high)
        #expect(result.canFormVersion)
    }

    @Test("Same artist and title with duration delta > 5s is strictly rejected from automatic versions")
    func durationMismatchRejectsAutoVersion() {
        // e.g. Studio version (3:54) vs Live / Extended version (5:10)
        let candStudio = AssetMatchCandidate(
            title: "Comfortably Numb",
            artist: "Pink Floyd",
            duration: 382.0
        )
        let candLive = AssetMatchCandidate(
            title: "Comfortably Numb",
            artist: "Pink Floyd",
            duration: 545.0 // 9+ minutes
        )

        let result = AssetMatcher.evaluate(source: candStudio, target: candLive)
        #expect(result.tier < .high)
        #expect(!result.canFormVersion)
        #expect(result.rationale.contains("Duration difference"))
    }

    @Test("High metadata similarity with close duration (<= 2s) can form versions")
    func closeDurationHighSimilarityCanFormVersion() {
        let candA = AssetMatchCandidate(
            title: "Yesterday",
            artist: "The Beatles",
            duration: 125.0
        )
        let candB = AssetMatchCandidate(
            title: "Yesterday",
            artist: "The Beatles",
            duration: 125.8
        )

        let result = AssetMatcher.evaluate(source: candA, target: candB)
        #expect(result.tier == .high)
        #expect(result.canFormVersion)
    }
}
