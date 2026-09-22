//
//  LibraryTrack.swift
//  MSRU
//

import Foundation

// MARK: - Library Repository Protocol

protocol LibraryRepository: Sendable {
    func loadTracks() async throws -> [LibraryTrack]
    func saveTracks(_ tracks: [LibraryTrack]) async throws
}

// MARK: - Playback Source

enum LibraryPlaybackSourceKind: String, Codable, Hashable, Sendable {
    case local
    case openverse

    // Future
    case jamendo
    case appleMusic
    case openSubsonic
}

struct LibraryPlaybackSource: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: LibraryPlaybackSourceKind
    let externalID: String?
    let localFileURL: URL?
    let remoteURL: URL?

    init(
        id: UUID = UUID(),
        kind: LibraryPlaybackSourceKind,
        externalID: String? = nil,
        localFileURL: URL? = nil,
        remoteURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.externalID = externalID
        self.localFileURL = localFileURL
        self.remoteURL = remoteURL
    }

    init(local track: LocalTrack) {
        self.init(
            kind: .local,
            externalID: String(describing: track.id),
            localFileURL: track.fileURL
        )
    }

    init(openverse track: OpenverseAudio) {
        self.init(
            kind: .openverse,
            externalID: track.id,
            remoteURL: track.mediaURL
        )
    }
}

// MARK: - Library Track

struct LibraryTrack: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artist: String
    var album: String?
    var duration: TimeInterval?
    var artworkURL: URL?
    var artworkReference: String?
    var sources: [LibraryPlaybackSource]
    let dateAdded: Date
    var lastPlayedAt: Date?

    var artworkData: Data? {
        artworkReference.flatMap { LocalArtworkStorage.shared.loadArtwork(relativePath: $0) }
    }

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        artworkReference: String? = nil,
        artworkData: Data? = nil,
        sources: [LibraryPlaybackSource] = [],
        dateAdded: Date = Date(),
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        if let artworkReference, !artworkReference.isEmpty {
            self.artworkReference = artworkReference
        } else if let artworkData, !artworkData.isEmpty {
            self.artworkReference = LocalArtworkStorage.shared.storeArtwork(artworkData)
        } else {
            self.artworkReference = nil
        }
        self.sources = sources
        self.dateAdded = dateAdded
        self.lastPlayedAt = lastPlayedAt
    }

    init(local track: LocalTrack) {
        let source = LibraryPlaybackSource(local: track)
        self.init(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration > 0 ? track.duration : nil,
            artworkReference: track.artworkReference,
            sources: [source]
        )
    }

    init(openverse track: OpenverseAudio) {
        let duration: TimeInterval?
        if let milliseconds = track.durationMilliseconds, milliseconds > 0 {
            duration = Double(milliseconds) / 1_000
        } else {
            duration = nil
        }

        let source = LibraryPlaybackSource(openverse: track)
        self.init(
            title: track.title,
            artist: track.creatorTitle,
            duration: duration,
            artworkURL: track.thumbnailURL,
            sources: [source]
        )
    }
}
