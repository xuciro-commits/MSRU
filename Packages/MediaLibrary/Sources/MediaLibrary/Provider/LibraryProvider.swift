//
//  LibraryProvider.swift
//  MediaLibrary
//
//  Contract for media library providers feeding catalog or live browsing.
//

import Foundation

public protocol LibraryProvider: Sendable {
    var sourceID: LibrarySourceID { get }
    var source: LibrarySource { get }
    var capabilities: LibraryCapabilities { get }

    func connect() async throws
    func disconnect() async throws
    func probeCapabilities() async throws -> LibraryCapabilities

    func fetchArtists() async throws -> [UnifiedArtist]
    func fetchAlbums(artistID: MediaID?) async throws -> [UnifiedAlbum]
    func fetchTracks(albumID: MediaID?) async throws -> [UnifiedTrack]
    func search(query: String) async throws -> UnifiedSearchResult
}

public extension LibraryProvider {
    func connect() async throws {}
    func disconnect() async throws {}
    func probeCapabilities() async throws -> LibraryCapabilities {
        capabilities
    }
}
