//
//  PicardAlbumLookupResolver.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import AppFoundation

/// Match pair between a local cluster item and an external catalog track.
public struct ClusterTrackMatch: Sendable, Equatable, Identifiable {
    public var id: String { localTrack.id }
    public let localTrack: ClusterTrackItem
    public let candidate: CatalogTrackCandidate?
    public let score: WeightedScoreResult

    public init(
        localTrack: ClusterTrackItem,
        candidate: CatalogTrackCandidate? = nil,
        score: WeightedScoreResult
    ) {
        self.localTrack = localTrack
        self.candidate = candidate
        self.score = score
    }
}

/// Comprehensive outcome of a Picard-style Cluster -> Lookup resolution.
public struct AlbumClusterLookupResult: Sendable, Equatable, Identifiable {
    public var id: String { cluster.id }
    public let cluster: AlbumCluster
    public let matchedRelease: ExternalReleaseMatch?
    public let confidence: Double
    public let tier: ConfidenceTier
    public let trackMatches: [ClusterTrackMatch]
    public let candidateReleases: [ExternalReleaseMatch]

    public init(
        cluster: AlbumCluster,
        matchedRelease: ExternalReleaseMatch? = nil,
        confidence: Double,
        tier: ConfidenceTier,
        trackMatches: [ClusterTrackMatch] = [],
        candidateReleases: [ExternalReleaseMatch] = []
    ) {
        self.cluster = cluster
        self.matchedRelease = matchedRelease
        self.confidence = confidence
        self.tier = tier
        self.trackMatches = trackMatches
        self.candidateReleases = candidateReleases
    }
}

/// Picard-style cluster-to-release lookup and disambiguation resolver.
public enum PicardAlbumLookupResolver {

    /// Resolves an album cluster against an external catalog service.
    public static func resolve(
        cluster: AlbumCluster,
        catalog: any ExternalCatalogService = MusicBrainzCatalogClient.shared
    ) async throws -> AlbumClusterLookupResult {
        // 1. Search candidate releases by album name and artist clues from cluster
        let artistClue = cluster.tracks.compactMap { $0.artist }.first ?? ""
        let albumClue = cluster.albumName ?? ""

        var candidateReleases = try await catalog.searchReleases(artist: artistClue, album: albumClue)

        // If no candidate by text search, try looking up release via recording MBID of first track
        if candidateReleases.isEmpty, let firstMBID = cluster.tracks.compactMap({ $0.trackMBID }).first {
            // Simulated fallback or recording lookup
            if let release = try await catalog.lookupRelease(releaseMBID: firstMBID) {
                candidateReleases = [release]
            }
        }

        guard !candidateReleases.isEmpty else {
            // No candidate release found -> Unidentified tier
            let fallbackMatches = cluster.tracks.map { track in
                ClusterTrackMatch(
                    localTrack: track,
                    candidate: nil,
                    score: WeightedScoreResult(confidence: 0.0, tier: .low, components: [])
                )
            }
            return AlbumClusterLookupResult(
                cluster: cluster,
                matchedRelease: nil,
                confidence: 0.0,
                tier: .low,
                trackMatches: fallbackMatches,
                candidateReleases: []
            )
        }

        // 2. Score candidate releases and select the best one
        var bestRelease: ExternalReleaseMatch? = nil
        var bestConfidence: Double = -1.0
        var bestTrackMatches: [ClusterTrackMatch] = []

        for release in candidateReleases {
            var currentMatches: [ClusterTrackMatch] = []
            var totalScore = 0.0

            for localTrack in cluster.tracks {
                // Find best matching track candidate in this release
                let query = MatchQuery(
                    trackMBID: localTrack.trackMBID,
                    title: localTrack.title,
                    artist: localTrack.artist,
                    album: release.title,
                    duration: localTrack.duration,
                    trackNumber: localTrack.trackNumber,
                    year: release.date.flatMap { Int($0.prefix(4)) }
                )

                var bestTrackSim = -1.0
                var bestCandidate: CatalogTrackCandidate? = nil
                var bestResult = WeightedScoreResult(confidence: 0.0, tier: .low, components: [])

                for catalogTrack in release.tracks {
                    let cand = CatalogTrackCandidate(
                        trackMBID: catalogTrack.recordingMBID ?? "",
                        releaseMBID: release.releaseMBID,
                        title: catalogTrack.title,
                        artist: release.artist,
                        artistAliases: [],
                        album: release.title,
                        duration: catalogTrack.duration,
                        trackNumber: catalogTrack.position,
                        year: release.date.flatMap { Int($0.prefix(4)) }
                    )

                    let scoreResult = MatchScorer.evaluate(query: query, against: cand)
                    if scoreResult.confidence > bestTrackSim {
                        bestTrackSim = scoreResult.confidence
                        bestCandidate = cand
                        bestResult = scoreResult
                    }
                }

                currentMatches.append(ClusterTrackMatch(
                    localTrack: localTrack,
                    candidate: bestCandidate,
                    score: bestResult
                ))
                totalScore += max(0.0, bestTrackSim)
            }

            let releaseConfidence = cluster.tracks.isEmpty ? 0.0 : (totalScore / Double(cluster.tracks.count))
            if releaseConfidence > bestConfidence {
                bestConfidence = releaseConfidence
                bestRelease = release
                bestTrackMatches = currentMatches
            }
        }

        let overallTier = ConfidenceTier(confidence: bestConfidence)

        return AlbumClusterLookupResult(
            cluster: cluster,
            matchedRelease: bestRelease,
            confidence: bestConfidence,
            tier: overallTier,
            trackMatches: bestTrackMatches,
            candidateReleases: candidateReleases
        )
    }
}
