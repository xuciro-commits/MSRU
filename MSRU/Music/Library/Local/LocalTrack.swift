//
//  LocalTrack.swift
//  MSRU
//

import Foundation


public struct LocalTrack:
    Identifiable,
    Hashable,
    Sendable,
    Codable {

    public let fileURL:
        URL

    public let title:
        String

    public let artist:
        String

    public let album:
        String?

    public let duration:
        TimeInterval

    public let artworkData:
        Data?

    public init(
        fileURL: URL,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkData: Data? = nil
    ) {
        self.fileURL = fileURL
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkData = artworkData
    }

    public var id: String {
        fileURL.absoluteString
    }
}
