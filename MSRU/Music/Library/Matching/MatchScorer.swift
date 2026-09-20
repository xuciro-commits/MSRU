//
//  MatchScorer.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import AppFoundation

/// Query metadata describing a local track candidate for identity matching.
nonisolated public struct MatchQuery: Sendable, Equatable {
    public var trackMBID: String?
    public var releaseMBID: String?
    public var title: String
    public var artist: String?
    public var album: String?
    public var duration: TimeInterval?
    public var trackNumber: Int?
    public var year: Int?

    public init(
        trackMBID: String? = nil,
        releaseMBID: String? = nil,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        trackNumber: Int? = nil,
        year: Int? = nil
    ) {
        self.trackMBID = trackMBID
        self.releaseMBID = releaseMBID
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.year = year
    }

    /// Convenience initializer from TrackMetadataOverlay.
    public init(from overlay: TrackMetadataOverlay, duration: TimeInterval? = nil) {
        self.init(
            title: overlay.resolvedTitle,
            artist: overlay.resolvedArtist,
            album: overlay.resolvedAlbum,
            duration: duration,
            trackNumber: overlay.resolvedTrackNumber,
            year: overlay.resolvedYear
        )
    }
}

/// Target authoritative catalog metadata entity against which a local track is compared.
nonisolated public struct CatalogTrackCandidate: Sendable, Equatable {
    public let trackMBID: String
    public let releaseMBID: String?
    public let title: String
    public let artist: String
    public let artistAliases: [String]
    public let album: String?
    public let duration: TimeInterval?
    public let trackNumber: Int?
    public let year: Int?

    public init(
        trackMBID: String,
        releaseMBID: String? = nil,
        title: String,
        artist: String,
        artistAliases: [String] = [],
        album: String? = nil,
        duration: TimeInterval? = nil,
        trackNumber: Int? = nil,
        year: Int? = nil
    ) {
        self.trackMBID = trackMBID
        self.releaseMBID = releaseMBID
        self.title = title
        self.artist = artist
        self.artistAliases = artistAliases
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.year = year
    }

    /// Convenience initializer from Recording and optional Release context.
    public init(recording: Recording, release: Release? = nil, trackNumber: Int? = nil, artistAliases: [String] = []) {
        self.init(
            trackMBID: recording.id,
            releaseMBID: release?.id,
            title: recording.title,
            artist: recording.artistCredit.headline,
            artistAliases: artistAliases,
            album: release?.title,
            duration: recording.duration,
            trackNumber: trackNumber,
            year: release?.date.flatMap { Int($0.prefix(4)) }
        )
    }
}

/// beets-style multi-criteria weighted distance scorer.
///
/// Implements:
/// - `album_id` / `track_id` (MBID): Weight 5.0
/// - `artist` / `album` / `track_title`: Weight 3.0
/// - `track_length` / `track_position`: Weight 2.0
/// - `year`: Weight 1.0
nonisolated public enum MatchScorer {

    public static let weightID: Double = 5.0
    public static let weightTitle: Double = 3.0
    public static let weightArtist: Double = 3.0
    public static let weightAlbum: Double = 3.0
    public static let weightDuration: Double = 2.0
    public static let weightPosition: Double = 2.0
    public static let weightYear: Double = 1.0

    /// Evaluates the match between local query metadata and a catalog candidate.
    public static func evaluate(query: MatchQuery, against candidate: CatalogTrackCandidate) -> WeightedScoreResult {
        var components: [WeightedComponent] = []

        // 1. MBID Match (weight 5.0)
        if let queryMBID = query.trackMBID, !queryMBID.isEmpty {
            let mbidSim = queryMBID.caseInsensitiveCompare(candidate.trackMBID) == .orderedSame ? 1.0 : 0.0
            components.append(WeightedComponent(name: "track_mbid", weight: weightID, similarity: mbidSim))
        }

        // 2. Title Match (weight 3.0)
        // Clean leading track number heuristic if present in query title
        let cleanedQueryTitle = FileNameHeuristicParser.parse(fileName: query.title).title
        let rawTitleSim = StringDistance.similarity(query.title, candidate.title)
        let cleanedTitleSim = StringDistance.similarity(cleanedQueryTitle, candidate.title)
        let titleSim = max(rawTitleSim, cleanedTitleSim)
        components.append(WeightedComponent(name: "title", weight: weightTitle, similarity: titleSim))

        // 3. Artist Match (weight 3.0)
        if let queryArtist = query.artist {
            var bestArtistSim = StringDistance.similarity(queryArtist, candidate.artist)
            for alias in candidate.artistAliases {
                let aliasSim = StringDistance.similarity(queryArtist, alias)
                if aliasSim > bestArtistSim {
                    bestArtistSim = aliasSim
                }
            }
            components.append(WeightedComponent(name: "artist", weight: weightArtist, similarity: bestArtistSim))
        }

        // 4. Album Match (weight 3.0)
        if let queryAlbum = query.album, let candidateAlbum = candidate.album {
            let albumSim = StringDistance.similarity(queryAlbum, candidateAlbum)
            components.append(WeightedComponent(name: "album", weight: weightAlbum, similarity: albumSim))
        }

        // 5. Duration Match (weight 2.0)
        if let queryDur = query.duration, let candDur = candidate.duration, queryDur > 0, candDur > 0 {
            let delta = abs(queryDur - candDur)
            // Gaussian/linear tolerance: 1.0 if within 1s, decays to 0.0 at 15s
            let durSim = delta <= 1.0 ? 1.0 : max(0.0, 1.0 - ((delta - 1.0) / 14.0))
            components.append(WeightedComponent(name: "duration", weight: weightDuration, similarity: durSim))
        }

        // 6. Track Number Match (weight 2.0)
        if let queryNum = query.trackNumber, let candNum = candidate.trackNumber {
            let numSim = queryNum == candNum ? 1.0 : 0.0
            components.append(WeightedComponent(name: "track_number", weight: weightPosition, similarity: numSim))
        }

        // 7. Year Match (weight 1.0)
        if let queryYear = query.year, let candYear = candidate.year {
            let yearDelta = abs(queryYear - candYear)
            let yearSim = yearDelta == 0 ? 1.0 : (yearDelta <= 2 ? 0.7 : 0.0)
            components.append(WeightedComponent(name: "year", weight: weightYear, similarity: yearSim))
        }

        return WeightedScoreCalculator.calculate(components: components)
    }
}
