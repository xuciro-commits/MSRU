//
//  UnifiedEntities.swift
//  MediaLibrary
//
//  Universal music domain entities shared across all sources (Local, Subsonic, etc.).
//

import Foundation

public struct UnifiedTrack: Identifiable, Hashable, Codable, Sendable {
    public let id: MediaID
    public var title: String
    public var artist: String
    public var artistID: MediaID?
    public var album: String?
    public var albumID: MediaID?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?
    public var duration: TimeInterval
    public var bitrateKbps: Int?
    public var sampleRate: Double?
    public var bitDepth: String?
    public var codec: String?
    public var artworkReference: String?
    public var isFavorite: Bool
    public var playCount: Int
    public var dateAdded: Date
    public var localFileURL: URL?

    public init(
        id: MediaID,
        title: String,
        artist: String,
        artistID: MediaID? = nil,
        album: String? = nil,
        albumID: MediaID? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        duration: TimeInterval = 0,
        bitrateKbps: Int? = nil,
        sampleRate: Double? = nil,
        bitDepth: String? = nil,
        codec: String? = nil,
        artworkReference: String? = nil,
        isFavorite: Bool = false,
        playCount: Int = 0,
        dateAdded: Date = Date(),
        localFileURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistID = artistID
        self.album = album
        self.albumID = albumID
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
        self.duration = duration
        self.bitrateKbps = bitrateKbps
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.codec = codec
        self.artworkReference = artworkReference
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.dateAdded = dateAdded
        self.localFileURL = localFileURL
    }
}

public struct UnifiedAlbum: Identifiable, Hashable, Codable, Sendable {
    public let id: MediaID
    public var title: String
    public var artist: String
    public var artistID: MediaID?
    public var year: Int?
    public var genre: String?
    public var trackCount: Int
    public var duration: TimeInterval
    public var artworkReference: String?

    public init(
        id: MediaID,
        title: String,
        artist: String,
        artistID: MediaID? = nil,
        year: Int? = nil,
        genre: String? = nil,
        trackCount: Int = 0,
        duration: TimeInterval = 0,
        artworkReference: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistID = artistID
        self.year = year
        self.genre = genre
        self.trackCount = trackCount
        self.duration = duration
        self.artworkReference = artworkReference
    }
}

public struct UnifiedArtist: Identifiable, Hashable, Codable, Sendable {
    public let id: MediaID
    public var name: String
    public var albumCount: Int
    public var trackCount: Int
    public var artworkReference: String?

    public init(
        id: MediaID,
        name: String,
        albumCount: Int = 0,
        trackCount: Int = 0,
        artworkReference: String? = nil
    ) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.trackCount = trackCount
        self.artworkReference = artworkReference
    }
}

public struct UnifiedPlaylist: Identifiable, Hashable, Codable, Sendable {
    public let id: MediaID
    public var name: String
    public var comment: String?
    public var trackCount: Int
    public var duration: TimeInterval
    public var isReadOnly: Bool
    public var dateCreated: Date?
    public var dateUpdated: Date?

    public init(
        id: MediaID,
        name: String,
        comment: String? = nil,
        trackCount: Int = 0,
        duration: TimeInterval = 0,
        isReadOnly: Bool = false,
        dateCreated: Date? = nil,
        dateUpdated: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.trackCount = trackCount
        self.duration = duration
        self.isReadOnly = isReadOnly
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
    }
}

public struct UnifiedSearchResult: Sendable {
    public var artists: [UnifiedArtist]
    public var albums: [UnifiedAlbum]
    public var tracks: [UnifiedTrack]

    public init(
        artists: [UnifiedArtist] = [],
        albums: [UnifiedAlbum] = [],
        tracks: [UnifiedTrack] = []
    ) {
        self.artists = artists
        self.albums = albums
        self.tracks = tracks
    }

    public var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && tracks.isEmpty
    }
}
