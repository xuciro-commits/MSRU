//
//  DuplicateCategory.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation

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
