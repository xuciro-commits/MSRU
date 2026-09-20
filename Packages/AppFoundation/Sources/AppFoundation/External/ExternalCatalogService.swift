//
//  ExternalCatalogService.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation

/// A recording match returned by an external metadata authority (e.g. AcoustID / MusicBrainz).
public struct ExternalRecordingMatch: Sendable, Equatable, Hashable, Codable, Identifiable {
    public var id: String { recordingMBID }
    public let recordingMBID: String
    public let title: String
    public let artist: String
    public let duration: TimeInterval?
    public let acoustIDScore: Double
    public let releaseMBIDs: [String]

    public init(
        recordingMBID: String,
        title: String,
        artist: String,
        duration: TimeInterval? = nil,
        acoustIDScore: Double = 1.0,
        releaseMBIDs: [String] = []
    ) {
        self.recordingMBID = recordingMBID
        self.title = title
        self.artist = artist
        self.duration = duration
        self.acoustIDScore = acoustIDScore
        self.releaseMBIDs = releaseMBIDs
    }
}

/// A track entry within an external release.
public struct ExternalTrackMatch: Sendable, Equatable, Hashable, Codable, Identifiable {
    public var id: Int { position }
    public let position: Int
    public let title: String
    public let recordingMBID: String?
    public let duration: TimeInterval?

    public init(
        position: Int,
        title: String,
        recordingMBID: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.position = position
        self.title = title
        self.recordingMBID = recordingMBID
        self.duration = duration
    }
}

/// A release candidate returned by an external metadata authority (e.g. MusicBrainz).
public struct ExternalReleaseMatch: Sendable, Equatable, Hashable, Codable, Identifiable {
    public var id: String { releaseMBID }
    public let releaseMBID: String
    public let releaseGroupMBID: String?
    public let title: String
    public let artist: String
    public let date: String?
    public let country: String?
    public let trackCount: Int
    public let tracks: [ExternalTrackMatch]

    public init(
        releaseMBID: String,
        releaseGroupMBID: String? = nil,
        title: String,
        artist: String,
        date: String? = nil,
        country: String? = nil,
        trackCount: Int,
        tracks: [ExternalTrackMatch] = []
    ) {
        self.releaseMBID = releaseMBID
        self.releaseGroupMBID = releaseGroupMBID
        self.title = title
        self.artist = artist
        self.date = date
        self.country = country
        self.trackCount = trackCount
        self.tracks = tracks
    }
}

/// Provider-agnostic abstraction for querying external metadata catalog entities and acoustic fingerprints.
public protocol ExternalCatalogService: Sendable {
    /// Queries recording candidates associated with an acoustic fingerprint.
    func lookupRecording(fingerprint: AudioFingerprint) async throws -> [ExternalRecordingMatch]

    /// Fetches complete details of a specific release by its authoritative MBID.
    func lookupRelease(releaseMBID: String) async throws -> ExternalReleaseMatch?

    /// Searches for release candidates matching artist name and album title.
    func searchReleases(artist: String, album: String) async throws -> [ExternalReleaseMatch]

    /// Fetches all known alias representations for a specific artist entity.
    func fetchArtistAliases(artistMBID: String) async throws -> [EntityAlias]
}
