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
    public let scoredCandidates: [ScoredReleaseCandidate]

    public init(
        cluster: AlbumCluster,
        matchedRelease: ExternalReleaseMatch? = nil,
        confidence: Double,
        tier: ConfidenceTier,
        trackMatches: [ClusterTrackMatch] = [],
        candidateReleases: [ExternalReleaseMatch] = [],
        scoredCandidates: [ScoredReleaseCandidate] = []
    ) {
        self.cluster = cluster
        self.matchedRelease = matchedRelease
        self.confidence = confidence
        self.tier = tier
        self.trackMatches = trackMatches
        self.candidateReleases = candidateReleases
        self.scoredCandidates = scoredCandidates
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
        var artistClue = cluster.tracks.compactMap { $0.artist }.first ?? ""
        var albumClue = cluster.albumName ?? ""

        if (albumClue.isEmpty || artistClue.isEmpty), let folder = cluster.folderURL?.lastPathComponent {
            let folderMeta = FileNameHeuristicParser.parseFolderMetadata(folder)
            if albumClue.isEmpty, let a = folderMeta.album { albumClue = a }
            if artistClue.isEmpty, let art = folderMeta.artist { artistClue = art }
        }

        var candidateReleases = try await catalog.searchReleases(artist: artistClue, album: albumClue)

        // Fallback: If artist + album returned empty, try album alone
        if candidateReleases.isEmpty && !albumClue.isEmpty && !artistClue.isEmpty {
            candidateReleases = try await catalog.searchReleases(artist: "", album: albumClue)
        }

        // If no candidate by text search, try looking up release via recording MBID of first track
        if candidateReleases.isEmpty, let firstMBID = cluster.tracks.compactMap({ $0.trackMBID }).first {
            // Simulated fallback or recording lookup
            if let release = try await catalog.lookupRelease(releaseMBID: firstMBID) {
                candidateReleases = [release]
            }
        }

        guard !candidateReleases.isEmpty else {
            // No candidate release found in MusicBrainz -> rely on acoustic fingerprint memory / AcoustID
            let fallbackMatches = cluster.tracks.map { track in
                fallbackTrackMatch(for: track, clusterAlbum: cluster.albumName)
            }
            let avgConfidence = cluster.tracks.isEmpty ? 0.0 : (fallbackMatches.reduce(0.0) { $0 + $1.score.confidence } / Double(cluster.tracks.count))
            let overallTier = ConfidenceTier(confidence: avgConfidence)

            let matchedRelease: ExternalReleaseMatch?
            if avgConfidence >= 0.7 {
                let repTitle = cluster.albumName ?? cluster.tracks.compactMap(\.matchedMemory?.album).first ?? "本地匹配专辑"
                let repArtist = cluster.tracks.compactMap(\.artist).first ?? cluster.tracks.compactMap(\.matchedMemory?.artist).first ?? "本地艺术家"
                matchedRelease = ExternalReleaseMatch(
                    releaseMBID: cluster.tracks.compactMap(\.matchedMemory?.releaseMBID).first ?? "local_acoustic_\(cluster.id)",
                    title: repTitle,
                    artist: repArtist,
                    date: nil,
                    trackCount: cluster.tracks.count
                )
            } else {
                matchedRelease = nil
            }

            return AlbumClusterLookupResult(
                cluster: cluster,
                matchedRelease: matchedRelease,
                confidence: avgConfidence,
                tier: overallTier,
                trackMatches: fallbackMatches,
                candidateReleases: []
            )
        }

        // 2. Enrich candidate releases: Fetch track listings if not already present
        var enrichedCandidates: [ExternalReleaseMatch] = []
        for rel in candidateReleases {
            if rel.tracks.isEmpty {
                if let full = try await catalog.lookupRelease(releaseMBID: rel.releaseMBID) {
                    enrichedCandidates.append(full)
                } else {
                    enrichedCandidates.append(rel)
                }
            } else {
                enrichedCandidates.append(rel)
            }
        }

        // 3. Score candidate releases and select the best one
        var bestRelease: ExternalReleaseMatch? = nil
        var bestConfidence: Double = 0.0
        var bestTrackMatches: [ClusterTrackMatch] = []

        for release in enrichedCandidates {
            var currentMatches: [ClusterTrackMatch] = []
            var totalScore = 0.0

            for localTrack in cluster.tracks {
                if localTrack.matchedMemory != nil || (localTrack.trackMBID != nil && !localTrack.trackMBID!.isEmpty) {
                    let match = fallbackTrackMatch(for: localTrack, release: release, clusterAlbum: release.title)
                    currentMatches.append(match)
                    totalScore += match.score.confidence
                    continue
                }

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
            if releaseConfidence > bestConfidence && releaseConfidence >= 0.05 {
                bestConfidence = releaseConfidence
                bestRelease = release
                bestTrackMatches = currentMatches
            }
        }

        if bestRelease == nil {
            let fallbackMatches = cluster.tracks.map { track in
                fallbackTrackMatch(for: track, clusterAlbum: cluster.albumName)
            }
            let avgConfidence = cluster.tracks.isEmpty ? 0.0 : (fallbackMatches.reduce(0.0) { $0 + $1.score.confidence } / Double(cluster.tracks.count))
            bestConfidence = avgConfidence
            bestTrackMatches = fallbackMatches

            if avgConfidence >= 0.7 {
                let repTitle = cluster.albumName ?? cluster.tracks.compactMap(\.matchedMemory?.album).first ?? "本地匹配专辑"
                let repArtist = cluster.tracks.compactMap(\.artist).first ?? cluster.tracks.compactMap(\.matchedMemory?.artist).first ?? "本地艺术家"
                bestRelease = ExternalReleaseMatch(
                    releaseMBID: cluster.tracks.compactMap(\.matchedMemory?.releaseMBID).first ?? "local_acoustic_\(cluster.id)",
                    title: repTitle,
                    artist: repArtist,
                    date: nil,
                    trackCount: cluster.tracks.count
                )
            }
        }

        let overallTier = ConfidenceTier(confidence: bestConfidence)
        let scoredCandidates = ExactReleaseResolver.rankCandidates(
            cluster: cluster,
            candidates: enrichedCandidates
        )

        return AlbumClusterLookupResult(
            cluster: cluster,
            matchedRelease: bestRelease,
            confidence: bestConfidence,
            tier: overallTier,
            trackMatches: bestTrackMatches,
            candidateReleases: candidateReleases,
            scoredCandidates: scoredCandidates
        )
    }

    private static func fallbackTrackMatch(
        for track: ClusterTrackItem,
        release: ExternalReleaseMatch? = nil,
        clusterAlbum: String? = nil
    ) -> ClusterTrackMatch {
        if let memory = track.matchedMemory {
            let cand = CatalogTrackCandidate(
                trackMBID: memory.recordingMBID ?? "",
                releaseMBID: memory.releaseMBID ?? (release?.releaseMBID ?? ""),
                title: memory.title,
                artist: memory.artist,
                artistAliases: [],
                album: memory.album ?? release?.title ?? clusterAlbum,
                duration: memory.duration,
                trackNumber: memory.trackNumber ?? track.trackNumber
            )
            return ClusterTrackMatch(
                localTrack: track,
                candidate: cand,
                score: WeightedScoreResult(
                    confidence: 1.0,
                    tier: .high,
                    components: [
                        WeightedComponent(name: "本地声纹记忆", weight: 1.0, similarity: 1.0)
                    ]
                )
            )
        } else if let trackMBID = track.trackMBID, !trackMBID.isEmpty {
            let cand = CatalogTrackCandidate(
                trackMBID: trackMBID,
                releaseMBID: release?.releaseMBID ?? "",
                title: track.title,
                artist: track.artist ?? (release?.artist ?? "Unknown Artist"),
                artistAliases: [],
                album: track.album ?? release?.title ?? clusterAlbum,
                duration: track.duration,
                trackNumber: track.trackNumber
            )
            return ClusterTrackMatch(
                localTrack: track,
                candidate: cand,
                score: WeightedScoreResult(
                    confidence: 0.95,
                    tier: .high,
                    components: [
                        WeightedComponent(name: "AcoustID 声学指纹", weight: 1.0, similarity: 0.95)
                    ]
                )
            )
        } else {
            return ClusterTrackMatch(
                localTrack: track,
                candidate: nil,
                score: WeightedScoreResult(confidence: 0.0, tier: .low, components: [])
            )
        }
    }
}
