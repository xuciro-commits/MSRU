//
//  PlaybackPolicy.swift
//  MSRU
//
//  Abstracts audio asset source and quality selection for playback.
//  Bans hardcoded static quality rankings in favor of user preferences and network-aware policies.
//

import Foundation
import AppFoundation

public struct PlaybackAssetCandidate: Identifiable, Sendable, Hashable {
    public let id: String
    public let assetID: AssetID
    public let sourceID: SourceID
    public let sourceType: SourceType
    public let format: String?
    public let bitrateKbps: Int?
    public let sampleRate: Int?
    public let isLossless: Bool
    public let isLocal: Bool

    public init(
        assetID: AssetID,
        sourceID: SourceID,
        sourceType: SourceType,
        format: String? = nil,
        bitrateKbps: Int? = nil,
        sampleRate: Int? = nil,
        isLossless: Bool = false,
        isLocal: Bool = false
    ) {
        self.id = assetID.rawValue
        self.assetID = assetID
        self.sourceID = sourceID
        self.sourceType = sourceType
        self.format = format
        self.bitrateKbps = bitrateKbps
        self.sampleRate = sampleRate
        self.isLossless = isLossless
        self.isLocal = isLocal
    }
}

public struct PlaybackPreference: Sendable, Hashable {
    public enum QualityMode: String, Sendable, Codable, CaseIterable {
        case highestQuality
        case preferLocal
        case bandwidthSaver
    }

    public var preferredSourceID: String?
    public var qualityMode: QualityMode

    public init(
        preferredSourceID: String? = nil,
        qualityMode: QualityMode = .highestQuality
    ) {
        self.preferredSourceID = preferredSourceID
        self.qualityMode = qualityMode
    }
}

public protocol PlaybackPolicy: Sendable {
    func selectCandidate(
        from candidates: [PlaybackAssetCandidate],
        preference: PlaybackPreference
    ) -> PlaybackAssetCandidate?
}

public struct StandardPlaybackPolicy: PlaybackPolicy {
    public init() {}

    public func selectCandidate(
        from candidates: [PlaybackAssetCandidate],
        preference: PlaybackPreference
    ) -> PlaybackAssetCandidate? {
        guard !candidates.isEmpty else { return nil }

        // 1. Explicit user source override
        if let targetSource = preference.preferredSourceID,
           let matched = candidates.first(where: { $0.sourceID.rawValue == targetSource }) {
            return matched
        }

        // 2. Mode evaluation
        switch preference.qualityMode {
        case .preferLocal:
            if let local = candidates.first(where: { $0.isLocal }) {
                return local
            }
            return candidates.first

        case .bandwidthSaver:
            // Prefer lossy with lowest bitrate
            return candidates.sorted {
                ($0.bitrateKbps ?? Int.max) < ($1.bitrateKbps ?? Int.max)
            }.first

        case .highestQuality:
            // Prefer lossless with highest sample rate, then highest bitrate lossy
            return candidates.sorted { a, b in
                if a.isLossless != b.isLossless {
                    return a.isLossless && !b.isLossless
                }
                if let srA = a.sampleRate, let srB = b.sampleRate, srA != srB {
                    return srA > srB
                }
                return (a.bitrateKbps ?? 0) > (b.bitrateKbps ?? 0)
            }.first
        }
    }
}
