//
//  TrackVersions.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation
import AppFoundation
import MusicDomain

/// A Roon-style multi-version collection aggregating alternative audio assets for a track/recording.
///
/// Encapsulates `AppFoundation.VersionGroup<AudioAsset>`, providing audiophile-aware
/// primary version election, manual user pinning, and UI presentation badge formatting.
nonisolated public struct TrackVersions: Identifiable, Sendable, Equatable, Codable {

    /// Stable recording identifier anchoring this version group.
    public let id: String

    /// Associated Recording MBID.
    public var recordingID: String

    /// Underlying generic version group managing asset alternatives.
    public var versionGroup: VersionGroup<AudioAsset>

    /// Explicit user-pinned primary asset ID, overriding automatic quality ranking.
    public var userDesignatedPrimaryID: String?

    /// Timestamp of last modification.
    public var lastUpdated: Date

    // MARK: - Initializers

    public init(
        recordingID: String,
        assets: [AudioAsset] = [],
        designatedPrimaryID: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = recordingID
        self.recordingID = recordingID
        self.userDesignatedPrimaryID = designatedPrimaryID
        self.lastUpdated = lastUpdated
        self.versionGroup = VersionGroup(id: recordingID, elements: assets, primaryID: designatedPrimaryID)

        if designatedPrimaryID == nil && !assets.isEmpty {
            autoSelectPrimaryByQuality()
        }
    }

    /// Convenience initializer with an initial primary asset.
    public init(primaryAsset: AudioAsset) {
        let recID = primaryAsset.recordingID ?? primaryAsset.id
        self.init(recordingID: recID, assets: [primaryAsset], designatedPrimaryID: nil)
    }

    // MARK: - Accessors

    /// The active primary asset (respects user manual pin, falling back to quality-ranked primary).
    public var primaryAsset: AudioAsset? {
        if let manualID = userDesignatedPrimaryID,
           let manualAsset = versionGroup.elements.first(where: { $0.id == manualID }) {
            return manualAsset
        }
        return versionGroup.primary
    }

    /// All alternative assets excluding the active primary.
    public var alternativeAssets: [AudioAsset] {
        guard let active = primaryAsset else { return [] }
        return versionGroup.elements.filter { $0.id != active.id }
    }

    /// Total count of versions available.
    public var versionCount: Int {
        versionGroup.count
    }

    /// Whether multiple alternative versions exist.
    public var hasMultipleVersions: Bool {
        versionGroup.hasAlternatives
    }

    /// Whether the current primary is an explicit user pin.
    public var isUserPinned: Bool {
        userDesignatedPrimaryID != nil
    }

    /// Formatted audiophile specification badge for the active primary asset.
    public var primaryBadgeText: String {
        guard let asset = primaryAsset else { return "No Asset" }
        let bitDepthStr = asset.bitDepth ?? (asset.isLossless ? "16-bit" : "")
        let sampleRateKHz = asset.sampleRate >= 1000 ? "\(Int(asset.sampleRate / 1000)) kHz" : "\(Int(asset.sampleRate)) Hz"

        var parts: [String] = []
        if !bitDepthStr.isEmpty {
            parts.append(bitDepthStr)
        }
        parts.append(sampleRateKHz)
        parts.append(asset.format)

        if asset.isHiRes {
            parts.append("(Hi-Res)")
        } else if asset.isLossless {
            parts.append("(Lossless)")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Mutating Operations

    /// Designates the primary asset using the highest audio quality score.
    public mutating func autoSelectPrimaryByQuality() {
        guard userDesignatedPrimaryID == nil else { return }
        versionGroup.selectPrimary(by: AudioQualityRanker.isHigherQuality)
        lastUpdated = Date()
    }

    /// Manually pins a specific asset ID as the primary version.
    public mutating func setManualPrimary(assetID: String) {
        if versionGroup.setPrimary(id: assetID) {
            userDesignatedPrimaryID = assetID
            lastUpdated = Date()
        }
    }

    /// Clears user manual pin and reverts to automatic quality ranking.
    public mutating func clearManualPrimary() {
        userDesignatedPrimaryID = nil
        autoSelectPrimaryByQuality()
        lastUpdated = Date()
    }

    /// Adds or updates an asset within this versions group.
    public mutating func addVersion(_ asset: AudioAsset, prioritizeIfBestQuality: Bool = true) {
        versionGroup.addOrUpdate(asset)
        if prioritizeIfBestQuality && userDesignatedPrimaryID == nil {
            autoSelectPrimaryByQuality()
        }
        lastUpdated = Date()
    }

    /// Removes an asset from the versions group.
    @discardableResult
    public mutating func removeVersion(assetID: String) -> AudioAsset? {
        let removed = versionGroup.remove(id: assetID)
        if userDesignatedPrimaryID == assetID {
            userDesignatedPrimaryID = nil
            autoSelectPrimaryByQuality()
        }
        lastUpdated = Date()
        return removed
    }
}
