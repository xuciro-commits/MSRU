//
//  DuplicateClassifier.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation
import AppFoundation

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
///
/// Implements Roon/MusicBrainz standards:
/// - A. File Duplicate (SHA256 match)
/// - B. Different Encoding (same Recording/AcoustID, different codec)
/// - C. Quality Difference (same Recording, different sample rate or bit depth)
/// - D. Different Master (same Work, different studio mastering/release)
/// - E. Different Performance (same Work, live vs studio, strictly not duplicate)
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
