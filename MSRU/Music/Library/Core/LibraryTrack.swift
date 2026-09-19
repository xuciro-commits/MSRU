//
//  LibraryTrack.swift
//  MSRU
//

import Foundation


struct LibraryTrack:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    let id:
        UUID


    var title:
        String

    var artist:
        String

    var album:
        String?


    var duration:
        TimeInterval?


    var artworkURL:
        URL?

    var artworkData:
        Data?


    var sources:
        [LibraryPlaybackSource]


    let dateAdded:
        Date

    var lastPlayedAt:
        Date?


    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        artworkData: Data? = nil,
        sources: [LibraryPlaybackSource] = [],
        dateAdded: Date = Date(),
        lastPlayedAt: Date? = nil
    ) {

        self.id =
            id

        self.title =
            title

        self.artist =
            artist

        self.album =
            album

        self.duration =
            duration

        self.artworkURL =
            artworkURL

        self.artworkData =
            artworkData

        self.sources =
            sources

        self.dateAdded =
            dateAdded

        self.lastPlayedAt =
            lastPlayedAt
    }
}
