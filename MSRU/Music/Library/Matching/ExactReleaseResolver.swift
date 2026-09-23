//
//  ExactReleaseResolver.swift
//  MSRU
//
//  Created for Acoustic Metadata Pipeline Architecture Phase 3.
//

import Foundation
import AppFoundation
import MusicDomain

/// A scored candidate release with comprehensive multi-factor breakdown.
public struct ScoredReleaseCandidate: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { release.releaseMBID }
    public let release: ExternalReleaseMatch
    public let totalScore: Double
    public let tier: ConfidenceTier
    public let disambiguationReason: String

    public let acoustIDScore: Double
    public let albumScore: Double
    public let artistScore: Double
    public let titleScore: Double
    public let trackOrderScore: Double
    public let durationScore: Double
    public let yearScore: Double
    public let folderScore: Double

    public init(
        release: ExternalReleaseMatch,
        totalScore: Double,
        tier: ConfidenceTier,
        disambiguationReason: String,
        acoustIDScore: Double = 0.0,
        albumScore: Double = 0.0,
        artistScore: Double = 0.0,
        titleScore: Double = 0.0,
        trackOrderScore: Double = 0.0,
        durationScore: Double = 0.0,
        yearScore: Double = 0.0,
        folderScore: Double = 0.0
    ) {
        self.release = release
        self.totalScore = totalScore
        self.tier = tier
        self.disambiguationReason = disambiguationReason
        self.acoustIDScore = acoustIDScore
        self.albumScore = albumScore
        self.artistScore = artistScore
        self.titleScore = titleScore
        self.trackOrderScore = trackOrderScore
        self.durationScore = durationScore
        self.yearScore = yearScore
        self.folderScore = folderScore
    }
}

/// 8-factor weighted scoring and disambiguation engine for selecting exact music releases.
///
/// Weights:
/// - AcoustID: 40%
/// - Album: 15%
/// - Title: 10%
/// - Artist: 10%
/// - Track Number / Count: 10%
/// - Duration: 5%
/// - Year: 5%
/// - Folder Context: 5%
public struct ExactReleaseResolver: Sendable {

    public static let weightAcoustID: Double = 0.40
    public static let weightAlbum: Double = 0.15
    public static let weightTitle: Double = 0.10
    public static let weightArtist: Double = 0.10
    public static let weightTrackOrder: Double = 0.10
    public static let weightDuration: Double = 0.05
    public static let weightYear: Double = 0.05
    public static let weightFolder: Double = 0.05

    /// Evaluates and ranks a list of candidate releases against a local cluster.
    public static func rankCandidates(
        cluster: AlbumCluster,
        candidates: [ExternalReleaseMatch],
        baseAcoustIDScore: Double = 0.95
    ) -> [ScoredReleaseCandidate] {
        guard !candidates.isEmpty else { return [] }

        var scored: [ScoredReleaseCandidate] = []

        let rawClusterAlbum = cluster.albumName ?? ""
        let clusterAlbum = FileNameHeuristicParser.isGenericFolderName(rawClusterAlbum) ? "" : rawClusterAlbum
        let clusterArtists = cluster.tracks.compactMap { $0.artist }
        let clusterArtist = clusterArtists.first ?? ""
        let folderPath = cluster.folderURL?.path.lowercased() ?? ""

        for candidate in candidates {
            // 1. AcoustID (40%)
            let sAcoustID = min(1.0, max(0.0, baseAcoustIDScore))

            // 2. Album Title Similarity (15%)
            let sAlbum = clusterAlbum.isEmpty ? 0.7 : StringDistance.similarity(clusterAlbum, candidate.title)

            // 3. Artist Similarity (10%)
            let sArtist = StringDistance.similarity(clusterArtist, candidate.artist)

            // 4. Track Title Match & Track Order Match (10% + 10%)
            var titleSimilarities: [Double] = []
            var matchedTrackCount = 0

            for localTrack in cluster.tracks {
                var bestTrackSim = 0.0
                for remoteTrack in candidate.tracks {
                    let sim = StringDistance.similarity(localTrack.title, remoteTrack.title)
                    if sim > bestTrackSim {
                        bestTrackSim = sim
                    }
                    if let localNum = localTrack.trackNumber, localNum == remoteTrack.position {
                        matchedTrackCount += 1
                    }
                }
                titleSimilarities.append(bestTrackSim)
            }

            let sTitle = titleSimilarities.isEmpty ? 0.5 : (titleSimilarities.reduce(0.0, +) / Double(titleSimilarities.count))

            let sTrackOrder: Double
            if candidate.trackCount > 0 {
                let countRatio = min(Double(cluster.tracks.count), Double(candidate.trackCount)) / max(Double(cluster.tracks.count), Double(candidate.trackCount))
                let orderRatio = cluster.tracks.isEmpty ? 0.0 : (Double(matchedTrackCount) / Double(cluster.tracks.count))
                sTrackOrder = (countRatio * 0.5) + (orderRatio * 0.5)
            } else {
                sTrackOrder = 0.5
            }

            // 5. Duration Proximity (5%)
            var durationScores: [Double] = []
            for localTrack in cluster.tracks {
                let lDur = localTrack.duration
                if lDur > 0 {
                    if let matchingRemote = candidate.tracks.first(where: { StringDistance.similarity(localTrack.title, $0.title) >= 0.7 }) {
                        if let rDur = matchingRemote.duration {
                            let diff = abs(lDur - rDur)
                            if diff <= 2.0 {
                                durationScores.append(1.0)
                            } else if diff <= 6.0 {
                                durationScores.append(0.8)
                            } else if diff <= 12.0 {
                                durationScores.append(0.5)
                            } else {
                                durationScores.append(0.2)
                            }
                        }
                    }
                }
            }
            let sDuration = durationScores.isEmpty ? 0.8 : (durationScores.reduce(0.0, +) / Double(durationScores.count))

            // 6. Year Alignment (5%)
            var sYear = 0.5
            if let releaseDate = candidate.date, !releaseDate.isEmpty {
                let releaseYear = String(releaseDate.prefix(4))
                if folderPath.contains(releaseYear) {
                    sYear = 1.0
                } else {
                    sYear = 0.7
                }
            }

            // 7. Folder Context Match (5%)
            var sFolder = 0.5
            let candidateLower = candidate.title.lowercased()
            if !candidateLower.isEmpty && folderPath.contains(candidateLower) {
                sFolder = 1.0
            } else if candidateLower.contains("remaster") && folderPath.contains("remaster") {
                sFolder = 0.9
            } else if candidateLower.contains("deluxe") && folderPath.contains("deluxe") {
                sFolder = 0.9
            }

            // Weighted aggregation
            let total = (sAcoustID * weightAcoustID) +
                        (sAlbum * weightAlbum) +
                        (sTitle * weightTitle) +
                        (sArtist * weightArtist) +
                        (sTrackOrder * weightTrackOrder) +
                        (sDuration * weightDuration) +
                        (sYear * weightYear) +
                        (sFolder * weightFolder)

            let tier: ConfidenceTier
            if total >= 0.92 {
                tier = .high
            } else if total >= 0.60 {
                tier = .medium
            } else {
                tier = .low
            }

            let pct = Int(round(total * 100))
            let yearInfo = candidate.date?.prefix(4).description ?? String(localized: "Unknown Year")
            let reason = "\(String(localized: "Confidence")) \(pct)% · \(candidate.artist) - 《\(candidate.title)》 (\(yearInfo)) · \(candidate.trackCount) \(String(localized: "tracks"))"

            scored.append(ScoredReleaseCandidate(
                release: candidate,
                totalScore: total,
                tier: tier,
                disambiguationReason: reason,
                acoustIDScore: sAcoustID,
                albumScore: sAlbum,
                artistScore: sArtist,
                titleScore: sTitle,
                trackOrderScore: sTrackOrder,
                durationScore: sDuration,
                yearScore: sYear,
                folderScore: sFolder
            ))
        }

        return scored.sorted { $0.totalScore > $1.totalScore }
    }
}
