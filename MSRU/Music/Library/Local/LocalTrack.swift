//
//  LocalTrack.swift
//  MSRU
//

import Foundation

nonisolated public struct LocalTrack:
    Identifiable,
    Hashable,
    Sendable,
    Codable {

    public let fileURL: URL
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval
    public let artworkReference: String?

    public init(
        fileURL: URL,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkReference: String? = nil,
        artworkData: Data? = nil
    ) {
        self.fileURL = fileURL
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        if let artworkReference, !artworkReference.isEmpty {
            self.artworkReference = artworkReference
        } else if let artworkData, !artworkData.isEmpty {
            self.artworkReference = LocalArtworkStorage.shared.storeArtwork(artworkData)
        } else {
            self.artworkReference = nil
        }
    }

    /// On-demand artwork loader for backward compatibility.
    /// In-memory resident size of LocalTrack does not retain the raw bytes.
    public var artworkData: Data? {
        artworkReference.flatMap { LocalArtworkStorage.shared.loadArtwork(relativePath: $0) }
    }

    public var id: String {
        fileURL.absoluteString
    }

    // MARK: - Codable Migration Compatibility

    enum CodingKeys: String, CodingKey {
        case fileURL
        case title
        case artist
        case album
        case duration
        case artworkReference
        case artworkData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        duration = try container.decode(TimeInterval.self, forKey: .duration)

        if let ref = try container.decodeIfPresent(String.self, forKey: .artworkReference), !ref.isEmpty {
            artworkReference = ref
        } else if let legacyData = try container.decodeIfPresent(Data.self, forKey: .artworkData), !legacyData.isEmpty {
            artworkReference = LocalArtworkStorage.shared.storeArtwork(legacyData)
        } else {
            artworkReference = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileURL, forKey: .fileURL)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(artworkReference, forKey: .artworkReference)
    }
}
