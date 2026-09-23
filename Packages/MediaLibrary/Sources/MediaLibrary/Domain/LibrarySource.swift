//
//  LibrarySource.swift
//  MediaLibrary
//
//  Representation of a media library source (local or remote).
//

import Foundation

public enum LibrarySourceKind: String, Codable, Sendable, CaseIterable {
    case local
    case subsonic
}

public enum LibrarySourceState: String, Codable, Sendable {
    case online
    case offline
    case syncing
    case authenticationRequired
    case error
}

public struct LibrarySource: Identifiable, Codable, Sendable, Hashable {
    public let id: LibrarySourceID
    public var name: String
    public var kind: LibrarySourceKind
    public var capabilities: LibraryCapabilities
    public var state: LibrarySourceState
    public var serverURL: URL?
    public var username: String?
    public var lastSyncAt: Date?
    public var totalTracks: Int?
    public var totalAlbums: Int?
    public var totalArtists: Int?
    public var errorMessage: String?

    public init(
        id: LibrarySourceID,
        name: String,
        kind: LibrarySourceKind,
        capabilities: LibraryCapabilities = .localDefault,
        state: LibrarySourceState = .online,
        serverURL: URL? = nil,
        username: String? = nil,
        lastSyncAt: Date? = nil,
        totalTracks: Int? = nil,
        totalAlbums: Int? = nil,
        totalArtists: Int? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.capabilities = capabilities
        self.state = state
        self.serverURL = serverURL
        self.username = username
        self.lastSyncAt = lastSyncAt
        self.totalTracks = totalTracks
        self.totalAlbums = totalAlbums
        self.totalArtists = totalArtists
        self.errorMessage = errorMessage
    }

    public static let local = LibrarySource(
        id: .local,
        name: "This Mac",
        kind: .local,
        capabilities: .localDefault,
        state: .online
    )
}
