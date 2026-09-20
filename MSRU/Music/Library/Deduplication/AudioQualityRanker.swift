//
//  AudioQualityRanker.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation

/// Calculated composite quality score for an audio asset.
nonisolated public struct AudioQualityScore: Comparable, Sendable, Equatable, Hashable, Codable {

    public let isLossless: Bool
    public let sampleRate: Double
    public let bitDepthBits: Int
    public let bitrateKbps: Int
    public let totalScore: Int

    public init(
        isLossless: Bool,
        sampleRate: Double,
        bitDepthBits: Int,
        bitrateKbps: Int
    ) {
        self.isLossless = isLossless
        self.sampleRate = sampleRate
        self.bitDepthBits = bitDepthBits
        self.bitrateKbps = bitrateKbps

        // Lossless formats (FLAC, ALAC, WAV) receive a dominant base tier (+1_000_000).
        let baseTier = isLossless ? 1_000_000 : 0
        let sampleRatePoints = Int(sampleRate / 100.0)
        let bitDepthPoints = bitDepthBits * 100
        let bitratePoints = bitrateKbps

        self.totalScore = baseTier + (sampleRatePoints * 10) + bitDepthPoints + bitratePoints
    }

    public static func < (lhs: AudioQualityScore, rhs: AudioQualityScore) -> Bool {
        if lhs.totalScore != rhs.totalScore {
            return lhs.totalScore < rhs.totalScore
        }
        if lhs.sampleRate != rhs.sampleRate {
            return lhs.sampleRate < rhs.sampleRate
        }
        if lhs.bitDepthBits != rhs.bitDepthBits {
            return lhs.bitDepthBits < rhs.bitDepthBits
        }
        return lhs.bitrateKbps < rhs.bitrateKbps
    }
}

/// Evaluates and ranks audio assets deterministically according to audiophile priority rules.
///
/// Hierarchy:
/// `Hi-Res Lossless (24/192 > 24/96) > CD Lossless (16/44.1) > High-bitrate Lossy (320k) > Standard Lossy (256k > 128k)`.
nonisolated public enum AudioQualityRanker {

    /// Parses the integer bit depth from string descriptors (e.g. "24-bit" -> 24).
    public static func parseBitDepthBits(from string: String?) -> Int {
        guard let string else { return 16 }
        let digits = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits) ?? 16
    }

    /// Evaluates the quantitative quality score for an audio asset.
    public static func score(for asset: AudioAsset) -> AudioQualityScore {
        let bitDepth = parseBitDepthBits(from: asset.bitDepth)
        let bitrate = asset.bitrateKbps ?? (asset.isLossless ? (bitDepth == 24 ? 2000 : 900) : 256)

        return AudioQualityScore(
            isLossless: asset.isLossless,
            sampleRate: asset.sampleRate,
            bitDepthBits: bitDepth,
            bitrateKbps: bitrate
        )
    }

    /// Returns `true` if `lhs` possesses strictly higher audio quality than `rhs`.
    public static func isHigherQuality(_ lhs: AudioAsset, than rhs: AudioAsset) -> Bool {
        score(for: lhs) > score(for: rhs)
    }
}
