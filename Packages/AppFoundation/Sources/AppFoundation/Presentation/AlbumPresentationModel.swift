//
//  AlbumPresentationModel.swift
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
    public let artworkURL: URL?
    public let trackCount: Int
    public let duration: TimeInterval
    public let audioQualityBadge: String?
    public let discs: [DiscTrackGroup]

    public init(
        id: String,
        title: String,
        artist: String,
        year: Int? = nil,
        artworkURL: URL? = nil,
        trackCount: Int,
        duration: TimeInterval,
        audioQualityBadge: String? = nil,
        discs: [DiscTrackGroup] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artworkURL = artworkURL
        self.trackCount = trackCount
        self.duration = duration
        self.audioQualityBadge = audioQualityBadge
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
