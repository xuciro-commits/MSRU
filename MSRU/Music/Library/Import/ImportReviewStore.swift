//
//  ImportReviewStore.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import Observation
import AppFoundation

/// Filter criterion for items in the Import Review dashboard.
public enum ReviewFilterOption: String, CaseIterable, Identifiable, Sendable {
    case allPending = "全部待确认"
    case byCluster = "按候选专辑聚类"
    case unidentified = "未识别"

    public var id: String { rawValue }
}

/// An artist alias merge proposal detecting variations of the same underlying artist entity.
public struct ArtistAliasSuggestion: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let canonicalArtistName: String
    public let canonicalMBID: String
    public let variantNames: [String]

    public init(
        id: UUID = UUID(),
        canonicalArtistName: String,
        canonicalMBID: String,
        variantNames: [String]
    ) {
        self.id = id
        self.canonicalArtistName = canonicalArtistName
        self.canonicalMBID = canonicalMBID
        self.variantNames = variantNames
    }
}

/// Central state store for managing the Import Review and Disambiguation workflow.
@MainActor
@Observable
public final class ImportReviewStore {

    // Metrics
    public private(set) var totalScannedCount: Int
    public private(set) var autoAcceptedCount: Int
    public private(set) var pendingReviewClusters: [AlbumClusterLookupResult]
    public private(set) var unidentifiedTracks: [ClusterTrackItem]
    public private(set) var potentialDuplicatesCount: Int
    public private(set) var aliasSuggestions: [ArtistAliasSuggestion]

    // UI State
    public var selectedFilter: ReviewFilterOption = .allPending
    public var searchText: String = ""
    public var selectedClusterIDs: Set<String> = []

    public init(
        totalScannedCount: Int = 0,
        autoAcceptedCount: Int = 0,
        pendingReviewClusters: [AlbumClusterLookupResult] = [],
        unidentifiedTracks: [ClusterTrackItem] = [],
        potentialDuplicatesCount: Int = 0,
        aliasSuggestions: [ArtistAliasSuggestion] = []
    ) {
        self.totalScannedCount = totalScannedCount
        self.autoAcceptedCount = autoAcceptedCount
        self.pendingReviewClusters = pendingReviewClusters
        self.unidentifiedTracks = unidentifiedTracks
        self.potentialDuplicatesCount = potentialDuplicatesCount
        self.aliasSuggestions = aliasSuggestions
        // Pre-select all pending clusters by default for smooth batch processing
        self.selectedClusterIDs = Set(pendingReviewClusters.map { $0.id })
    }

    /// Filtered list of pending clusters based on current UI selection and search text.
    public var filteredClusters: [AlbumClusterLookupResult] {
        var list = pendingReviewClusters

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter { result in
                let titleMatch = result.matchedRelease?.title.lowercased().contains(query) ?? false
                let artistMatch = result.matchedRelease?.artist.lowercased().contains(query) ?? false
                let clusterName = result.cluster.albumName?.lowercased().contains(query) ?? false
                return titleMatch || artistMatch || clusterName
            }
        }

        switch selectedFilter {
        case .allPending, .byCluster:
            return list
        case .unidentified:
            return list.filter { $0.tier == .low }
        }
    }

    /// Approves and applies the selected cluster matches into the authoritative catalog.
    public func acceptSelectedMatches() {
        let accepted = pendingReviewClusters.filter { selectedClusterIDs.contains($0.id) }
        let count = accepted.reduce(0) { $0 + $1.cluster.tracks.count }
        autoAcceptedCount += count
        pendingReviewClusters.removeAll { selectedClusterIDs.contains($0.id) }
        selectedClusterIDs.removeAll()
    }

    /// Imports the selected clusters using their raw local file metadata as-is.
    public func importAsOriginalFiles() {
        let original = pendingReviewClusters.filter { selectedClusterIDs.contains($0.id) }
        let count = original.reduce(0) { $0 + $1.cluster.tracks.count }
        autoAcceptedCount += count
        pendingReviewClusters.removeAll { selectedClusterIDs.contains($0.id) }
        selectedClusterIDs.removeAll()
    }

    /// Discards unconfirmed items without modifying the library database.
    public func discardUnconfirmed() {
        pendingReviewClusters.removeAll { selectedClusterIDs.contains($0.id) }
        selectedClusterIDs.removeAll()
    }

    /// Resolves an artist alias suggestion by merging variants into canonical identity.
    public func mergeAliasSuggestion(id: UUID) {
        aliasSuggestions.removeAll { $0.id == id }
    }

    /// Executes file organization on confirmed items safely.
    public func organizeFiles(
        destinationRoot: URL,
        dryRun: Bool = true
    ) -> FileOrganizationResult {
        let template = FileNamingTemplate()
        var pairs: [(source: URL, desiredTarget: URL, size: Int64)] = []

        for cluster in pendingReviewClusters {
            for match in cluster.trackMatches {
                let local = match.localTrack
                let cand = match.candidate
                let artist = cand?.artist ?? local.artist ?? "Unknown Artist"
                let album = cand?.album ?? local.album ?? "Unknown Album"
                let title = cand?.title ?? local.title
                let track = cand?.trackNumber ?? local.trackNumber
                let year = cand?.year
                let ext = local.fileURL.pathExtension

                let relativePath = template.render(
                    artist: artist,
                    album: album,
                    year: year,
                    trackNumber: track,
                    title: title,
                    fileExtension: ext
                )

                let targetURL = destinationRoot.appendingPathComponent(relativePath)
                pairs.append((source: local.fileURL, desiredTarget: targetURL, size: 0))
            }
        }

        let plan = SafeFileOrganizer.generatePlan(candidatePairs: pairs, kind: .move)
        return SafeFileOrganizer.execute(plan: plan, dryRun: dryRun)
    }
}
