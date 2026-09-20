//
//  ArtistPresentationModel.swift
//  AppFoundation
//

import Foundation

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
