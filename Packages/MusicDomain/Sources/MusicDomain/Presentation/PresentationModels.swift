//
//  PresentationModels.swift
//  AppFoundation
//

import Foundation

// MARK: - Track Presentation Model

public struct TrackPresentationModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let trackNumber: Int
    public let title: String
    public let artist: String
    public let duration: TimeInterval
    public let formatBadge: String?
    public let versionCount: Int

    public init(
        id: String,
        trackNumber: Int,
        title: String,
        artist: String,
        duration: TimeInterval,
        formatBadge: String? = nil,
        versionCount: Int = 1
    ) {
        self.id = id
        self.trackNumber = trackNumber
        self.title = title
        self.artist = artist
        self.duration = duration
        self.formatBadge = formatBadge
        self.versionCount = versionCount
    }

    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Disc Track Group

public struct DiscTrackGroup: Identifiable, Hashable, Sendable {
    public var id: Int { discNumber }
    public let discNumber: Int
    public let discTitle: String?
    public let tracks: [TrackPresentationModel]

    public init(
        discNumber: Int = 1,
        discTitle: String? = nil,
        tracks: [TrackPresentationModel]
    ) {
        self.discNumber = discNumber
        self.discTitle = discTitle
        self.tracks = tracks
    }
}

// MARK: - Album Presentation Model

public struct AlbumPresentationModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let year: Int?
    public let artworkData: Data?
    public let artworkURL: URL?
    public let artworkReference: String?
    public let trackCount: Int
    public let duration: TimeInterval
    public let audioQualityBadge: String?
    public let sourceBadge: String?
    public let versionCount: Int
    public let discs: [DiscTrackGroup]

    public init(
        id: String,
        title: String,
        artist: String,
        year: Int? = nil,
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        artworkReference: String? = nil,
        trackCount: Int,
        duration: TimeInterval,
        audioQualityBadge: String? = nil,
        sourceBadge: String? = nil,
        versionCount: Int = 1,
        discs: [DiscTrackGroup] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.artworkReference = artworkReference
        self.trackCount = trackCount
        self.duration = duration
        self.audioQualityBadge = audioQualityBadge
        self.sourceBadge = sourceBadge
        self.versionCount = versionCount
        self.discs = discs
    }

    public var allTracks: [TrackPresentationModel] {
        discs.flatMap(\.tracks)
    }

    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Artist Presentation Model

public struct ArtistPresentationModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let aliases: [String]
    public let country: String?
    public let albumCount: Int
    public let trackCount: Int
    public let artworkData: Data?
    public let artworkURL: URL?
    public let artworkReference: String?
    public let biography: String?
    public let lifeSpan: String?
    public let genres: [String]

    public init(
        id: String,
        name: String,
        aliases: [String] = [],
        country: String? = nil,
        albumCount: Int = 0,
        trackCount: Int = 0,
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        artworkReference: String? = nil,
        biography: String? = nil,
        lifeSpan: String? = nil,
        genres: [String] = []
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.country = country
        self.albumCount = albumCount
        self.trackCount = trackCount
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.artworkReference = artworkReference
        self.biography = biography
        self.lifeSpan = lifeSpan
        self.genres = genres
    }

    public var displaySubtitle: String {
        var parts: [String] = []
        if albumCount > 0 {
            parts.append("\(albumCount) \(albumCount == 1 ? "album" : "albums")")
        }
        if trackCount > 0 {
            parts.append("\(trackCount) \(trackCount == 1 ? "song" : "songs")")
        }
        return parts.isEmpty ? "Artist" : parts.joined(separator: " • ")
    }
}
