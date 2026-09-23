//
//  MediaLibraryService.swift
//  MediaLibrary
//
//  Non-MainActor service layer executing catalog aggregation, queries, and background operations.
//  Serves as the shared engine for UI Coordinator, Server, and Background Sync Jobs.
//

import Foundation

public protocol MediaLibraryService: Sendable {
    var registry: LibraryProviderRegistry { get }

    func artists(source: LibrarySourceID?) async throws -> [UnifiedArtist]
    func albums(source: LibrarySourceID?, artistID: MediaID?) async throws -> [UnifiedAlbum]
    func tracks(source: LibrarySourceID?, albumID: MediaID?) async throws -> [UnifiedTrack]
    func search(query: String, source: LibrarySourceID?) async throws -> UnifiedSearchResult
}

public final class DefaultMediaLibraryService: MediaLibraryService, Sendable {
    public let registry: LibraryProviderRegistry

    public init(registry: LibraryProviderRegistry = LibraryProviderRegistry()) {
        self.registry = registry
    }

    public func artists(source: LibrarySourceID? = nil) async throws -> [UnifiedArtist] {
        if let source {
            guard let provider = registry.provider(for: source) else {
                throw RemoteLibraryError.resourceNotFound(id: source.rawValue)
            }
            return try await provider.fetchArtists()
        }

        var results: [UnifiedArtist] = []
        for provider in registry.allProviders() {
            if let artists = try? await provider.fetchArtists() {
                results.append(contentsOf: artists)
            }
        }
        return results
    }

    public func albums(source: LibrarySourceID? = nil, artistID: MediaID? = nil) async throws -> [UnifiedAlbum] {
        if let source {
            guard let provider = registry.provider(for: source) else {
                throw RemoteLibraryError.resourceNotFound(id: source.rawValue)
            }
            return try await provider.fetchAlbums(artistID: artistID)
        }

        var results: [UnifiedAlbum] = []
        for provider in registry.allProviders() {
            if let albums = try? await provider.fetchAlbums(artistID: artistID) {
                results.append(contentsOf: albums)
            }
        }
        return results
    }

    public func tracks(source: LibrarySourceID? = nil, albumID: MediaID? = nil) async throws -> [UnifiedTrack] {
        if let source {
            guard let provider = registry.provider(for: source) else {
                throw RemoteLibraryError.resourceNotFound(id: source.rawValue)
            }
            return try await provider.fetchTracks(albumID: albumID)
        }

        var results: [UnifiedTrack] = []
        for provider in registry.allProviders() {
            if let tracks = try? await provider.fetchTracks(albumID: albumID) {
                results.append(contentsOf: tracks)
            }
        }
        return results
    }

    public func search(query: String, source: LibrarySourceID? = nil) async throws -> UnifiedSearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UnifiedSearchResult() }

        if let source {
            guard let provider = registry.provider(for: source) else {
                throw RemoteLibraryError.resourceNotFound(id: source.rawValue)
            }
            return try await provider.search(query: trimmed)
        }

        var aggregated = UnifiedSearchResult()
        for provider in registry.allProviders() {
            if let res = try? await provider.search(query: trimmed) {
                aggregated.artists.append(contentsOf: res.artists)
                aggregated.albums.append(contentsOf: res.albums)
                aggregated.tracks.append(contentsOf: res.tracks)
            }
        }
        return aggregated
    }
}
