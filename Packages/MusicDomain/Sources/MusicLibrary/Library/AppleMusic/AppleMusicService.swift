//
//  AppleMusicService.swift
//  MSRU
//

import Foundation
import MusicKit
import Observation
import MusicDomain

// MARK: - Options

public struct LibraryImportOptions: Equatable {
    public var importsArtists = true
    public var importsSongs = true
    public var importsAlbums = true

    public var hasSelection: Bool {
        importsArtists || importsSongs || importsAlbums
    }

    nonisolated public init() {}
}

// MARK: - Service Protocol & Implementation

@MainActor
public protocol AppleMusicLibraryServing {
    func requestAuthorization() async -> MusicAuthorization.Status
    func fetchAlbums() async throws -> [Album]
    func fetchArtists() async throws -> [Artist]
    func fetchSongs() async throws -> [Song]
}

public struct AppleMusicService: AppleMusicLibraryServing {
    public func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }

    public func fetchAlbums() async throws -> [Album] {
        try await fetchAll(Album.self)
    }

    public func fetchArtists() async throws -> [Artist] {
        try await fetchAll(Artist.self)
    }

    public func fetchSongs() async throws -> [Song] {
        try await fetchAll(Song.self)
    }

    private func fetchAll<Item>(_ type: Item.Type) async throws -> [Item] where Item: MusicLibraryRequestable {
        let pageSize = 100
        var offset = 0
        var result: [Item] = []

        while true {
            var request = MusicLibraryRequest<Item>()
            request.limit = pageSize
            request.offset = offset

            let response = try await request.response()
            let page = Array(response.items)
            result.append(contentsOf: page)

            guard page.count == pageSize else { break }
            offset += page.count
        }

        return result
    }

    nonisolated public init() {}
}

// MARK: - Apple Music Library Store

@MainActor
@Observable
public final class AppleMusicLibraryStore {
    // MARK: - Content
    public private(set) var albums: [Album] = []
    public private(set) var artists: [Artist] = []
    public private(set) var songs: [Song] = []

    // MARK: - State
    public private(set) var authorizationStatus: MusicAuthorization.Status
    public private(set) var isImporting = false
    public private(set) var lastError: String?

    // MARK: - Service
    private let service: any AppleMusicLibraryServing

    public convenience init() {
        self.init(service: AppleMusicService(), authorizationStatus: MusicAuthorization.currentStatus)
    }

    public init(service: any AppleMusicLibraryServing, authorizationStatus: MusicAuthorization.Status) {
        self.service = service
        self.authorizationStatus = authorizationStatus
    }

    // MARK: - Summary
    public var hasContent: Bool {
        !albums.isEmpty || !artists.isEmpty || !songs.isEmpty
    }

    public var albumCount: Int {
        albums.count
    }

    public var artistCount: Int {
        artists.count
    }

    public var songCount: Int {
        songs.count
    }

    // MARK: - Import
    @discardableResult
    public func importLibrary(options: LibraryImportOptions) async -> Bool {
        guard options.hasSelection else { return false }

        isImporting = true
        lastError = nil
        defer { isImporting = false }

        let status = await service.requestAuthorization()
        authorizationStatus = status

        guard status == .authorized else {
            lastError = "Apple Music access was not authorized."
            return false
        }

        do {
            if options.importsAlbums {
                albums = try await service.fetchAlbums()
            }
            if options.importsArtists {
                artists = try await service.fetchArtists()
            }
            if options.importsSongs {
                songs = try await service.fetchSongs()
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
