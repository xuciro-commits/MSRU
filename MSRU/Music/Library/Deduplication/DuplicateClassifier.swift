//
//  DuplicateClassifier.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation
import AppFoundation

// MARK: - Deduplication Enums

/// Recommended handling strategy for duplicate resolution.
nonisolated public enum DeduplicationStrategy: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    /// Exact binary duplicate; safe to prune or hard-link one physical file.
    case safeDeduplicateFile

    /// Different encoding containers (e.g. FLAC vs MP3); co-exist for hi-fi and mobile scenarios.
    case coexistEncodings

    /// Same recording with varying sample rates or bit depths; group into TrackVersions and elect primary.
    case groupByQualitySelectPrimary

    /// Different mastering, mixing, or release issues; preserve all under the parent ReleaseGroup.
    case keepSeparateReleases

    /// Different live or studio performances of the same work; treat as distinct Recordings, strictly do not merge.
    case treatAsDistinctRecordings

    /// Unrelated tracks; no action.
    case none
}

/// The 5 architectural categories of music duplicate analysis (aligned with IdentityResolutionEngine Section 3).
nonisolated public enum DuplicateCategory: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    /// A. 物理重复 (File Duplicate): Exact binary duplicate (identical SHA256 checksum).
    case fileDuplicate

    /// B. 格式不同 (Different Encoding): Same recording and acoustID, different container codec (e.g. FLAC vs MP3).
    case differentEncoding

    /// C. 音质差异 (Different Quality): Same recording, different quantization/sampling (e.g. 16/44.1 CD vs 24/96 Hi-Res).
    case qualityDifference

    /// D. 版本/混音差异 (Different Master): Same musical composition, different release master (e.g. 1982 Original vs 2011 Remaster).
    case differentMaster

    /// E. 演出差异 (Different Performance): Same musical composition, different performance capture (e.g. Studio vs Live 1994).
    case differentPerformance

    /// Unrelated tracks.
    case none

    /// User-facing descriptive title.
    public var title: String {
        switch self {
        case .fileDuplicate:
            return String(localized: "File Duplicate")
        case .differentEncoding:
            return String(localized: "Different Encoding")
        case .qualityDifference:
            return String(localized: "Different Quality")
        case .differentMaster:
            return String(localized: "Different Master")
        case .differentPerformance:
            return String(localized: "Different Performance")
        case .none:
            return String(localized: "Distinct Tracks")
        }
    }

    /// Corresponding resolution action strategy.
    public var actionStrategy: DeduplicationStrategy {
        switch self {
        case .fileDuplicate:
            return .safeDeduplicateFile
        case .differentEncoding:
            return .coexistEncodings
        case .qualityDifference:
            return .groupByQualitySelectPrimary
        case .differentMaster:
            return .keepSeparateReleases
        case .differentPerformance:
            return .treatAsDistinctRecordings
        case .none:
            return .none
        }
    }

    /// Whether it is completely safe to eliminate one of the physical file references.
    public var isSafeToMerge: Bool {
        self == .fileDuplicate
    }

    /// Whether the items represent the exact same recording event.
    public var isSameRecording: Bool {
        switch self {
        case .fileDuplicate, .differentEncoding, .qualityDifference:
            return true
        case .differentMaster, .differentPerformance, .none:
            return false
        }
    }

    /// Whether the items represent the same underlying musical composition.
    public var isSameWork: Bool {
        self != .none
    }
}

// MARK: - Audio Quality Ranking

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

// MARK: - Duplicate Classifier

/// Detailed analysis output from comparing two audio assets and their identity graph context.
nonisolated public struct DuplicateAnalysisResult: Sendable, Equatable, Hashable, Codable {
    /// The resolved duplicate category (A~E or none).
    public let category: DuplicateCategory

    /// The recommended primary asset ID between the two, evaluated by audio quality and reliability.
    public let preferredAssetID: String?

    /// Action strategy for resolving this pair.
    public var actionStrategy: DeduplicationStrategy {
        category.actionStrategy
    }

    /// Diagnostic explanation.
    public let rationale: String

    public init(
        category: DuplicateCategory,
        preferredAssetID: String? = nil,
        rationale: String = ""
    ) {
        self.category = category
        self.preferredAssetID = preferredAssetID
        self.rationale = rationale
    }
}

/// Evaluates pairs of audio assets against the 5 music duplicate criteria.
nonisolated public enum DuplicateClassifier {

    /// Classifies the duplicate relationship between two audio assets and optional graph entities.
    public static func classify(
        assetA: AudioAsset,
        recordingA: Recording? = nil,
        workA: Work? = nil,
        releaseA: Release? = nil,
        assetB: AudioAsset,
        recordingB: Recording? = nil,
        workB: Work? = nil,
        releaseB: Release? = nil
    ) -> DuplicateAnalysisResult {
        // 1. Check A: 物理重复 (File Duplicate) via SHA256 or exact file path
        if let shaA = assetA.sha256, let shaB = assetB.sha256, !shaA.isEmpty, shaA == shaB {
            return DuplicateAnalysisResult(
                category: .fileDuplicate,
                preferredAssetID: assetA.id,
                rationale: "SHA256 checksums match exactly (\(shaA.prefix(12))...). Safe to prune duplicate file reference."
            )
        }
        if assetA.fileURL == assetB.fileURL && assetA.fileSize == assetB.fileSize && assetA.fileSize > 0 {
            return DuplicateAnalysisResult(
                category: .fileDuplicate,
                preferredAssetID: assetA.id,
                rationale: "Points to identical local path with identical byte size."
            )
        }

        // 2. Check Recording Identity
        let isSameRecording = evaluateIsSameRecording(
            assetA: assetA,
            recordingA: recordingA,
            assetB: assetB,
            recordingB: recordingB
        )

        let preferredID = AudioQualityRanker.isHigherQuality(assetA, than: assetB) ? assetA.id : assetB.id

        if isSameRecording {
            // Check C: 音质差异 (Different Quality)
            let bitDepthA = AudioQualityRanker.parseBitDepthBits(from: assetA.bitDepth)
            let bitDepthB = AudioQualityRanker.parseBitDepthBits(from: assetB.bitDepth)
            let sampleRateDiffers = assetA.sampleRate != assetB.sampleRate
            let bitDepthDiffers = bitDepthA != bitDepthB

            if sampleRateDiffers || bitDepthDiffers {
                let higherQualityDesc = AudioQualityRanker.isHigherQuality(assetA, than: assetB)
                    ? "\(assetA.format) (\(bitDepthA)-bit/\(Int(assetA.sampleRate))Hz)"
                    : "\(assetB.format) (\(bitDepthB)-bit/\(Int(assetB.sampleRate))Hz)"

                return DuplicateAnalysisResult(
                    category: .qualityDifference,
                    preferredAssetID: preferredID,
                    rationale: "Same recording with quality tiers. Preferred: \(higherQualityDesc). Group into TrackVersions."
                )
            }

            // Check B: 格式不同 (Different Encoding)
            return DuplicateAnalysisResult(
                category: .differentEncoding,
                preferredAssetID: preferredID,
                rationale: "Same recording audio content in different formats (\(assetA.format) vs \(assetB.format)). Coexist for audiophile and portable playback."
            )
        }

        // 3. Check Work Identity
        let isSameWork = evaluateIsSameWork(
            recordingA: recordingA,
            workA: workA,
            recordingB: recordingB,
            workB: workB
        )

        if isSameWork {
            let isLiveA = recordingA?.isLive ?? false
            let isLiveB = recordingB?.isLive ?? false
            let durationDelta = abs(assetA.duration - assetB.duration)

            // Check E: 演出差异 (Different Performance: Live vs Studio or distinct concert captures)
            if isLiveA != isLiveB || (isLiveA && isLiveB && durationDelta > 3.0) || durationDelta > 10.0 {
                return DuplicateAnalysisResult(
                    category: .differentPerformance,
                    preferredAssetID: nil,
                    rationale: "Different performances of '\(workA?.title ?? workB?.title ?? "Work")' (Studio vs Live or distinct concert takes). Not duplicates!"
                )
            }

            // Check D: 版本/混音差异 (Different Master: Remasters, Atmos mixes, Original)
            return DuplicateAnalysisResult(
                category: .differentMaster,
                preferredAssetID: preferredID,
                rationale: "Different mastering releases of the same work composition. Retain all under the ReleaseGroup."
            )
        }

        // 4. Distinct / Unrelated
        return DuplicateAnalysisResult(
            category: .none,
            preferredAssetID: nil,
            rationale: "Completely unrelated tracks."
        )
    }

    // MARK: - Helper Evaluators

    private static func evaluateIsSameRecording(
        assetA: AudioAsset,
        recordingA: Recording?,
        assetB: AudioAsset,
        recordingB: Recording?
    ) -> Bool {
        // Direct recording MBID match
        if let recA = assetA.recordingID ?? recordingA?.id,
           let recB = assetB.recordingID ?? recordingB?.id,
           !recA.isEmpty, recA == recB {
            return true
        }

        // AcoustID acoustic fingerprint match with duration tolerance
        if let acoustA = assetA.acoustID ?? recordingA?.acoustID,
           let acoustB = assetB.acoustID ?? recordingB?.acoustID,
           !acoustA.isEmpty, acoustA == acoustB {
            let durationDelta = abs(assetA.duration - assetB.duration)
            if durationDelta <= 3.0 {
                return true
            }
        }

        // ISRC match
        if let isrcA = recordingA?.isrc, let isrcB = recordingB?.isrc, !isrcA.isEmpty, isrcA == isrcB {
            return true
        }

        return false
    }

    private static func evaluateIsSameWork(
        recordingA: Recording?,
        workA: Work?,
        recordingB: Recording?,
        workB: Work?
    ) -> Bool {
        // Direct work ID match
        if let wA = workA?.id ?? recordingA?.workID,
           let wB = workB?.id ?? recordingB?.workID,
           !wA.isEmpty, wA == wB {
            return true
        }

        // ISWC code match
        if let iswcA = workA?.iswc, let iswcB = workB?.iswc, !iswcA.isEmpty, iswcA == iswcB {
            return true
        }

        // Title and composition match
        if let titleA = workA?.title ?? recordingA?.title,
           let titleB = workB?.title ?? recordingB?.title,
           !titleA.isEmpty,
           titleA.caseInsensitiveCompare(titleB) == .orderedSame {
            // Check composers if available
            if let compA = workA?.composers.first?.canonicalName,
               let compB = workB?.composers.first?.canonicalName,
               compA.caseInsensitiveCompare(compB) == .orderedSame {
                return true
            }
            // If title and primary artist match
            if let artA = recordingA?.artistCredit.headline,
               let artB = recordingB?.artistCredit.headline,
               artA.caseInsensitiveCompare(artB) == .orderedSame {
                return true
            }
        }

        return false
    }
}
