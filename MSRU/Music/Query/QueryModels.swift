//
//  QueryModels.swift
//  MSRU
//
//  Lightweight query specifications and UI row/card projections.
//  Decoupled from full domain models and storage engines.
//

import Foundation

nonisolated public enum QuerySortField: String, Sendable, CaseIterable {
    case title
    case artist
    case album
    case duration
    case dateAdded = "date_added"
}

nonisolated public struct QuerySpec: Sendable, Hashable {
    public var query: String
    public var sortField: QuerySortField
    public var ascending: Bool
    public var offset: Int
    public var limit: Int?

    nonisolated public init(
        query: String = "",
        sortField: QuerySortField = .title,
        ascending: Bool = true,
        offset: Int = 0,
        limit: Int? = nil
    ) {
        self.query = query
        self.sortField = sortField
        self.ascending = ascending
        self.offset = offset
        self.limit = limit
    }
}

nonisolated public struct TrackRowSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let recordingID: RecordingID
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: Double
    public let trackNumber: Int?
    public let year: Int?
    public let artworkReference: String?
    public var isFavorite: Bool

    nonisolated public init(
        id: String,
        recordingID: RecordingID,
        title: String,
        artist: String,
        album: String? = nil,
        duration: Double = 0,
        trackNumber: Int? = nil,
        year: Int? = nil,
        artworkReference: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.recordingID = recordingID
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.year = year
        self.artworkReference = artworkReference
        self.isFavorite = isFavorite
    }
}

nonisolated public struct AlbumCardSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let year: Int?
    public let trackCount: Int
    public let artworkReference: String?

    nonisolated public init(
        id: String,
        title: String,
        artist: String,
        year: Int? = nil,
        trackCount: Int = 0,
        artworkReference: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.trackCount = trackCount
        self.artworkReference = artworkReference
    }
}

nonisolated public struct ArtistCardSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let trackCount: Int
    public let albumCount: Int

    nonisolated public init(
        id: String,
        name: String,
        trackCount: Int = 0,
        albumCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.trackCount = trackCount
        self.albumCount = albumCount
    }
}
