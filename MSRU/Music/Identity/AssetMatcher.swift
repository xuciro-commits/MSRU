//
//  AssetMatcher.swift
//  MSRU
//
//  Evidence-based asset matching engine.
//  Strictly bans automatic merging purely on "same artist + same title".
//  Requires high confidence (>= 0.90) from acoustic signatures, MBID, or duration-bounded metadata.
//

import Foundation
import AppFoundation

nonisolated public struct AssetMatchCandidate: Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: Double
    public let exactSignature: String?
    public let acoustid: String?
    public let mbid: String?

    public init(
        title: String,
        artist: String,
        album: String? = nil,
        duration: Double,
        exactSignature: String? = nil,
        acoustid: String? = nil,
        mbid: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.exactSignature = exactSignature
        self.acoustid = acoustid
        self.mbid = mbid
    }
}

nonisolated public struct AssetMatchResult: Sendable {
    public let score: Double
    public let tier: ConfidenceTier
    public let rationale: String

    public var canFormVersion: Bool {
        tier == .high
    }
}

nonisolated public enum AssetMatcher {

    public static func evaluate(
        source: AssetMatchCandidate,
        target: AssetMatchCandidate
    ) -> AssetMatchResult {
        // 1. Exact Audio Signature Match (Bit-exact audio PCM)
        if let sigA = source.exactSignature, let sigB = target.exactSignature, !sigA.isEmpty, sigA == sigB {
            return AssetMatchResult(score: 1.0, tier: .high, rationale: "Identical exact audio signature")
        }

        // 2. Authoritative External Identifier (MBID or AcoustID)
        if let mbidA = source.mbid, let mbidB = target.mbid, !mbidA.isEmpty, mbidA == mbidB {
            return AssetMatchResult(score: 0.95, tier: .high, rationale: "Matching MusicBrainz recording MBID")
        }

        if let aidA = source.acoustid, let aidB = target.acoustid, !aidA.isEmpty, aidA == aidB {
            return AssetMatchResult(score: 0.95, tier: .high, rationale: "Matching AcoustID fingerprint")
        }

        // 3. String Text & Duration Match
        let titleSim = StringDistance.similarity(source.title, target.title)
        let artistSim = StringDistance.similarity(source.artist, target.artist)

        let durationDelta = abs(source.duration - target.duration)

        // Strict Duration Penalty: If duration differs by > 5 seconds, it is a different cut/remix/live version
        if durationDelta > 5.0 {
            let degradedScore = min(0.50, (titleSim * 0.5 + artistSim * 0.5) * 0.6)
            return AssetMatchResult(
                score: degradedScore,
                tier: ConfidenceTier(confidence: degradedScore),
                rationale: "Duration difference (\(String(format: "%.1f", durationDelta))s > 5s) prevents automatic version consolidation"
            )
        }

        // High metadata similarity with close duration (<= 2s)
        if titleSim >= 0.95 && artistSim >= 0.90 && durationDelta <= 2.0 {
            let score = 0.90 + (1.0 - durationDelta / 2.0) * 0.05
            return AssetMatchResult(
                score: score,
                tier: .high,
                rationale: "High title/artist similarity (\(String(format: "%.0f%%", titleSim * 100))) and matching duration"
            )
        }

        // Medium match (requires manual review or separate entities)
        let composite = (titleSim * 0.6 + artistSim * 0.4) * (durationDelta <= 3.0 ? 1.0 : 0.8)
        return AssetMatchResult(
            score: composite,
            tier: ConfidenceTier(confidence: composite),
            rationale: "Moderate metadata similarity without definitive evidence"
        )
    }
}
