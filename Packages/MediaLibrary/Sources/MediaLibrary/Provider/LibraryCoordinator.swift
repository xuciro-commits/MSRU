//
//  LibraryCoordinator.swift
//  MediaLibrary
//
//  Single point of access for UI querying unified library catalog across sources.
//  Acts as @MainActor UI facade on top of Sendable non-MainActor MediaLibraryService.
//

import Foundation
import Observation

@MainActor
@Observable
public final class LibraryCoordinator {
    public let service: any MediaLibraryService
    public var registry: LibraryProviderRegistry { service.registry }
    public private(set) var sources: [LibrarySource] = []
    public private(set) var isBusy: Bool = false
    public private(set) var activeError: String?

    public init(service: any MediaLibraryService) {
        self.service = service
        self.sources = service.registry.allSources()
    }

    public convenience init(registry: LibraryProviderRegistry = LibraryProviderRegistry()) {
        self.init(service: DefaultMediaLibraryService(registry: registry))
    }

    public func refreshSources() {
        self.sources = service.registry.allSources()
    }

    public func albums(source: LibrarySourceID? = nil, artistID: MediaID? = nil) async throws -> [UnifiedAlbum] {
        try await service.albums(source: source, artistID: artistID)
    }

    public func artists(source: LibrarySourceID? = nil) async throws -> [UnifiedArtist] {
        try await service.artists(source: source)
    }

    public func tracks(source: LibrarySourceID? = nil, albumID: MediaID? = nil) async throws -> [UnifiedTrack] {
        try await service.tracks(source: source, albumID: albumID)
    }

    public func search(_ query: String, source: LibrarySourceID? = nil) async throws -> UnifiedSearchResult {
        try await service.search(query: query, source: source)
    }
}
