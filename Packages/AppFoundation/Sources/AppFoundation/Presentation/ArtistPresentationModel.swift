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
    public let artworkURL: URL?

    public init(
        id: String,
        name: String,
        aliases: [String] = [],
        country: String? = nil,
        albumCount: Int = 0,
        trackCount: Int = 0,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.country = country
        self.albumCount = albumCount
        self.trackCount = trackCount
        self.artworkURL = artworkURL
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
