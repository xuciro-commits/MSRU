//
//  AppleMusicService.swift
//  MSRU
//

import Foundation
import MusicKit
import Observation
import MusicDomain

// MARK: - Options

public struct LibraryImportOptions: Equatable, Sendable {
    public var importsArtists = true
    public var importsSongs = true
    public var importsAlbums = true
    public var importsPlaylists = true

    public var hasSelection: Bool {
        importsArtists || importsSongs || importsAlbums || importsPlaylists
    }

    nonisolated public init() {}
}

// MARK: - Service Protocol & Implementation

@MainActor
public protocol AppleMusicLibraryServing: Sendable {
    func requestAuthorization() async -> MusicAuthorization.Status
    func fetchAlbums() async throws -> [Album]
    func fetchArtists() async throws -> [Artist]
    func fetchSongs() async throws -> [Song]
    func fetchPlaylists() async throws -> [MusicKit.Playlist]
}

public extension AppleMusicLibraryServing {
    func fetchPlaylists() async throws -> [MusicKit.Playlist] { [] }
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

    public func fetchPlaylists() async throws -> [MusicKit.Playlist] {
        try await fetchAll(MusicKit.Playlist.self)
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
    public private(set) var playlists: [MusicKit.Playlist] = []

    // MARK: - State
    public private(set) var authorizationStatus: MusicAuthorization.Status
    public private(set) var isImporting = false
    public private(set) var importProgress: Double = 0.0
    public private(set) var importStatusText: String = ""
    public private(set) var lastError: String?
    public private(set) var importedTrackCount: Int = 0

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
        !albums.isEmpty || !artists.isEmpty || !songs.isEmpty || !playlists.isEmpty || importedTrackCount > 0
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

    public var playlistCount: Int {
        playlists.count
    }

    public var isAuthorizationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Conversion
    public func convertSongsToTracks(_ songs: [Song]) -> [LocalTrack] {
        var tracks: [LocalTrack] = []
        var seenIDs = Set<String>()

        for song in songs {
            let rawID = song.id.rawValue
            guard seenIDs.insert(rawID).inserted else { continue }

            let fileURL = URL(fileURLWithPath: "/AppleMusic/Tracks/\(rawID).m4a")
            let artworkURLString = song.artwork?.url(width: 1400, height: 1400)?.absoluteString

            let year: Int?
            if let releaseDate = song.releaseDate {
                year = Calendar.current.component(.year, from: releaseDate)
            } else {
                year = nil
            }

            let track = LocalTrack(
                fileURL: fileURL,
                title: song.title,
                artist: song.artistName,
                album: song.albumTitle,
                duration: song.duration ?? 0,
                artworkReference: artworkURLString,
                artworkData: nil,
                trackNumber: song.trackNumber,
                year: year
            )
            tracks.append(track)
        }
        return tracks
    }

    // MARK: - Import
    @discardableResult
    public func importLibrary(
        options: LibraryImportOptions,
        into localStore: LocalLibraryStore? = nil,
        playlistStore: PlaylistStore? = nil
    ) async -> Bool {
        guard options.hasSelection else { return false }

        isImporting = true
        lastError = nil
        importProgress = 0.05
        importStatusText = String(localized: "Checking Apple Music authorization…")
        defer { isImporting = false }

        let status = await service.requestAuthorization()
        authorizationStatus = status

        guard status == .authorized else {
            lastError = String(localized: "Apple Music access was not authorized. Please grant permission in System Settings > Privacy & Security > Media & Apple Music.")
            importStatusText = ""
            return false
        }

        do {
            var songsToIngest: [Song] = []

            // 1. Fetch songs if requested
            if options.importsSongs {
                importProgress = 0.20
                importStatusText = String(localized: "Scanning songs from Apple Music…")
                let fetchedSongs = try await service.fetchSongs()
                songs = fetchedSongs
                songsToIngest = fetchedSongs
            }

            // 2. Fetch albums if requested
            if options.importsAlbums {
                importProgress = 0.45
                importStatusText = String(localized: "Scanning albums from Apple Music…")
                albums = try await service.fetchAlbums()
            }

            // 3. Fetch artists if requested
            if options.importsArtists {
                importProgress = 0.65
                importStatusText = String(localized: "Scanning artists from Apple Music…")
                artists = try await service.fetchArtists()
            }

            // 4. Fetch playlists if requested
            if options.importsPlaylists {
                importProgress = 0.80
                importStatusText = String(localized: "Scanning playlists from Apple Music…")
                let fetchedPlaylists = try await service.fetchPlaylists()
                playlists = fetchedPlaylists
            }

            // 5. Ingest into localStore
            if let localStore {
                importProgress = 0.88
                importStatusText = String(localized: "Ingesting tracks into MSRU library…")
                let converted = convertSongsToTracks(songsToIngest)
                if !converted.isEmpty {
                    try await localStore.addTracks(converted)
                    importedTrackCount = converted.count
                }
            }

            // 6. Ingest playlists into playlistStore if available
            if let playlistStore, options.importsPlaylists, !playlists.isEmpty {
                importProgress = 0.95
                importStatusText = String(localized: "Creating playlists…")
                for playlist in playlists {
                    let name = playlist.name
                    guard !name.isEmpty else { continue }
                    var trackIDs: [String] = []
                    if let detailed = try? await playlist.with([.tracks]), let pTracks = detailed.tracks {
                        for t in pTracks {
                            let trackURL = URL(fileURLWithPath: "/AppleMusic/Tracks/\(t.id.rawValue).m4a")
                            trackIDs.append(trackURL.absoluteString)
                        }
                    }
                    _ = await playlistStore.createPlaylist(
                        title: name,
                        description: playlist.description,
                        initialTrackIDs: trackIDs
                    )
                }
            }

            importProgress = 1.0
            importStatusText = String(localized: "Import completed successfully!")
            return true
        } catch {
            lastError = error.localizedDescription
            importStatusText = ""
            return false
        }
    }
}
