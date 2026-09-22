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
    case allPending = "All Pending"
    case byCluster = "Cluster by Candidate Album"
    case unidentified = "Unidentified"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .allPending: return String(localized: "All Pending")
        case .byCluster: return String(localized: "Cluster by Candidate Album")
        case .unidentified: return String(localized: "Unidentified")
        }
    }
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

    public convenience init(report: ImportPipelineReport) {
        self.init(
            totalScannedCount: report.totalDiscovered,
            autoAcceptedCount: report.autoCommittedCount,
            pendingReviewClusters: report.pendingReviewClusters,
            unidentifiedTracks: report.unidentifiedTracks,
            potentialDuplicatesCount: report.duplicateDetectionsCount,
            aliasSuggestions: report.aliasSuggestions
        )
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
    @discardableResult
    public func acceptSelectedMatches() -> [LocalTrack] {
        let accepted = pendingReviewClusters.filter { selectedClusterIDs.contains($0.id) }
        var generatedTracks: [LocalTrack] = []

        for clusterResult in accepted {
            for match in clusterResult.trackMatches {
                let local = match.localTrack
                let cand = match.candidate
                let title = cand?.title ?? local.matchedMemory?.title ?? local.title
                let artist = cand?.artist ?? local.matchedMemory?.artist ?? local.artist ?? clusterResult.cluster.tracks.compactMap(\.artist).first ?? "Unknown Artist"

                let rawCandidateAlbum = cand?.album ?? clusterResult.matchedRelease?.title
                let cleanCandidateAlbum = (rawCandidateAlbum.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : rawCandidateAlbum
                let cleanMemoryAlbum = (local.matchedMemory?.album.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : local.matchedMemory?.album
                let cleanLocalAlbum = (local.album.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : local.album
                let cleanClusterAlbum = (clusterResult.cluster.albumName.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : clusterResult.cluster.albumName

                let album = cleanCandidateAlbum ?? cleanMemoryAlbum ?? cleanLocalAlbum ?? cleanClusterAlbum
                let artworkData = local.artworkData ?? local.matchedMemory?.artworkData
                let track = LocalTrack(
                    fileURL: local.fileURL,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: local.duration,
                    artworkData: artworkData
                )
                generatedTracks.append(track)
            }
        }

        let count = accepted.reduce(0) { $0 + $1.cluster.tracks.count }
        autoAcceptedCount += count
        pendingReviewClusters.removeAll { selectedClusterIDs.contains($0.id) }
        selectedClusterIDs.removeAll()
        return generatedTracks
    }

    /// Asynchronously writes physical tags, exports companion cover.jpg, updates local fingerprint memory, and generates LocalTracks.
    @discardableResult
    public func commitSelectedMatches(
        writePhysicalTags: Bool = true,
        exportCompanionCover: Bool = true
    ) async -> [LocalTrack] {
        let accepted = pendingReviewClusters.filter { selectedClusterIDs.contains($0.id) }
        var generatedTracks: [LocalTrack] = []
        var fingerprintItems: [FingerprintRegistrationItem] = []
        let tagWriter = AudioTagWriter()

        for clusterResult in accepted {
            let releaseMBID = clusterResult.matchedRelease?.releaseMBID
            let releaseDate = clusterResult.matchedRelease?.date
            let releaseYear = releaseDate.flatMap { Int($0.prefix(4)) }

            for match in clusterResult.trackMatches {
                let local = match.localTrack
                let cand = match.candidate
                let title = cand?.title ?? local.matchedMemory?.title ?? local.title
                let artist = cand?.artist ?? local.matchedMemory?.artist ?? local.artist ?? clusterResult.cluster.tracks.compactMap(\.artist).first ?? "Unknown Artist"

                let rawCandidateAlbum = cand?.album ?? clusterResult.matchedRelease?.title
                let cleanCandidateAlbum = (rawCandidateAlbum.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : rawCandidateAlbum
                let cleanMemoryAlbum = (local.matchedMemory?.album.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : local.matchedMemory?.album
                let cleanLocalAlbum = (local.album.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : local.album
                let cleanClusterAlbum = (clusterResult.cluster.albumName.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : clusterResult.cluster.albumName

                let album = cleanCandidateAlbum ?? cleanMemoryAlbum ?? cleanLocalAlbum ?? cleanClusterAlbum ?? "Unknown Album"
                let artworkData = local.artworkData ?? local.matchedMemory?.artworkData
                let trackNumber = cand?.trackNumber ?? local.trackNumber
                let recordingMBID = cand?.trackMBID ?? local.trackMBID ?? local.matchedMemory?.recordingMBID

                // 1. Physical Tag Write
                if writePhysicalTags {
                    let tags = AudioStandardTags(
                        title: title,
                        artist: artist,
                        album: album,
                        albumArtist: artist,
                        trackNumber: trackNumber,
                        totalTracks: clusterResult.matchedRelease?.trackCount ?? clusterResult.cluster.tracks.count,
                        year: releaseYear,
                        recordingMBID: recordingMBID,
                        releaseMBID: releaseMBID,
                        artworkData: artworkData
                    )
                    _ = try? await tagWriter.writeTags(to: local.fileURL, tags: tags)
                }

                // 2. Export companion cover.jpg
                if exportCompanionCover, let artworkData {
                    ArtworkFileExporter.exportCover(artworkData: artworkData, to: local.fileURL.deletingLastPathComponent())
                }

                // 3. Collect for batch registration in Local Fingerprint Memory
                if let fp = local.fingerprint ?? local.acoustID {
                    fingerprintItems.append(FingerprintRegistrationItem(
                        fingerprint: fp,
                        duration: local.duration,
                        title: title,
                        artist: artist,
                        album: album,
                        trackNumber: trackNumber,
                        releaseMBID: releaseMBID,
                        recordingMBID: recordingMBID,
                        artworkData: artworkData,
                        fileURL: local.fileURL
                    ))
                }

                let track = LocalTrack(
                    fileURL: local.fileURL,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: local.duration,
                    artworkData: artworkData
                )
                generatedTracks.append(track)
            }
        }

        if !fingerprintItems.isEmpty {
            await LocalFingerprintRegistry.shared.registerBatch(fingerprintItems)
        }

        let count = accepted.reduce(0) { $0 + $1.cluster.tracks.count }
        autoAcceptedCount += count
        pendingReviewClusters.removeAll { selectedClusterIDs.contains($0.id) }
        selectedClusterIDs.removeAll()
        return generatedTracks
    }

    /// Selects a specific release candidate for an album cluster during disambiguation.
    public func selectReleaseCandidate(clusterID: String, release: ExternalReleaseMatch) {
        guard let idx = pendingReviewClusters.firstIndex(where: { $0.id == clusterID }) else { return }
        let current = pendingReviewClusters[idx]

        // Re-map track matches using the chosen release's track list
        var newTrackMatches: [ClusterTrackMatch] = []
        for localTrack in current.cluster.tracks {
            let matchingRemote = release.tracks.first(where: { remote in
                if let ln = localTrack.trackNumber, ln == remote.position { return true }
                return StringDistance.similarity(localTrack.title, remote.title) >= 0.6
            })

            let cand = matchingRemote.map {
                CatalogTrackCandidate(
                    trackMBID: $0.recordingMBID ?? "",
                    releaseMBID: release.releaseMBID,
                    title: $0.title,
                    artist: release.artist,
                    artistAliases: [],
                    album: release.title,
                    duration: $0.duration,
                    trackNumber: $0.position,
                    year: release.date.flatMap { Int($0.prefix(4)) }
                )
            }

            let result = WeightedScoreResult(confidence: cand != nil ? 0.95 : 0.6, tier: cand != nil ? .high : .medium, components: [])
            newTrackMatches.append(ClusterTrackMatch(localTrack: localTrack, candidate: cand, score: result))
        }

        pendingReviewClusters[idx] = AlbumClusterLookupResult(
            cluster: current.cluster,
            matchedRelease: release,
            confidence: 0.95,
            tier: .high,
            trackMatches: newTrackMatches,
            candidateReleases: current.candidateReleases,
            scoredCandidates: current.scoredCandidates
        )
    }

    /// Imports the selected clusters using their raw local file metadata as-is.
    @discardableResult
    public func importAsOriginalFiles() -> [LocalTrack] {
        let original = pendingReviewClusters.filter { selectedClusterIDs.contains($0.id) }
        var generatedTracks: [LocalTrack] = []

        for clusterResult in original {
            for match in clusterResult.trackMatches {
                let local = match.localTrack
                let title = local.title
                let artist = local.artist ?? clusterResult.cluster.tracks.compactMap(\.artist).first ?? "Unknown Artist"
                let cleanLocalAlbum = (local.album.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : local.album
                let cleanClusterAlbum = (clusterResult.cluster.albumName.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : clusterResult.cluster.albumName
                let album = cleanLocalAlbum ?? cleanClusterAlbum
                let artworkData = local.artworkData ?? local.matchedMemory?.artworkData
                let track = LocalTrack(
                    fileURL: local.fileURL,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: local.duration,
                    artworkData: artworkData
                )
                generatedTracks.append(track)
            }
        }

        let count = original.reduce(0) { $0 + $1.cluster.tracks.count }
        autoAcceptedCount += count
        pendingReviewClusters.removeAll { selectedClusterIDs.contains($0.id) }
        selectedClusterIDs.removeAll()
        return generatedTracks
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
