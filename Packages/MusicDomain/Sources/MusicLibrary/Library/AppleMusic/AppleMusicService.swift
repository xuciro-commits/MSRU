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

        var request = MusicLibraryRequest<Item>()
        request.limit = pageSize
        request.offset = offset

        let response = try await request.response()
        var currentBatch = response.items
        result.append(contentsOf: Array(currentBatch))

        while currentBatch.hasNextBatch {
            guard let next = try await currentBatch.nextBatch(limit: pageSize) else { break }
            result.append(contentsOf: Array(next))
            currentBatch = next
        }

        // If pagination is driven by offset instead of nextBatch
        if result.count == pageSize && !currentBatch.hasNextBatch {
            offset += pageSize
            while true {
                var nextRequest = MusicLibraryRequest<Item>()
                nextRequest.limit = pageSize
                nextRequest.offset = offset
                let nextResp = try await nextRequest.response()
                let page = Array(nextResp.items)
                if page.isEmpty { break }
                result.append(contentsOf: page)
                if page.count < pageSize { break }
                offset += page.count
            }
        }

        return result
    }

    nonisolated public init() {}

    // MARK: - Conversion & Lookup

    public static func convert(song: Song) -> LocalTrack {
        let rawID = song.id.rawValue
        let fileURL = URL(fileURLWithPath: "/AppleMusic/Tracks/\(rawID).m4a")
        let artworkURLString = song.artwork?.url(width: 1400, height: 1400)?.absoluteString
        let year = song.releaseDate.map { Calendar.current.component(.year, from: $0) }
        return LocalTrack(
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
    }

    public static func convert(
        track: Track,
        albumTitle: String? = nil,
        albumArtist: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil
    ) -> LocalTrack {
        if case .song(let song) = track {
            let base = convert(song: song)
            let finalAlbum = (base.album == nil || base.album?.isEmpty == true) ? albumTitle : base.album
            let finalArtist = (base.artist.isEmpty || base.artist == "Unknown Artist") ? (albumArtist ?? base.artist) : base.artist
            return LocalTrack(
                fileURL: base.fileURL,
                title: base.title,
                artist: finalArtist,
                album: finalAlbum,
                duration: base.duration,
                artworkReference: base.artworkReference,
                artworkData: nil,
                trackNumber: base.trackNumber ?? trackNumber,
                year: base.year ?? year
            )
        }
        let rawID = track.id.rawValue
        let fileURL = URL(fileURLWithPath: "/AppleMusic/Tracks/\(rawID).m4a")
        let artworkURLString = track.artwork?.url(width: 1400, height: 1400)?.absoluteString
        let artistName = track.artistName.isEmpty ? (albumArtist ?? "Unknown Artist") : track.artistName
        return LocalTrack(
            fileURL: fileURL,
            title: track.title,
            artist: artistName,
            album: albumTitle,
            duration: track.duration ?? 0,
            artworkReference: artworkURLString,
            artworkData: nil,
            trackNumber: trackNumber,
            year: year
        )
    }

    public static func lookupTrack(catalogID: String) async -> LocalTrack? {
        // 1. Try library
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.filter(matching: \.id, equalTo: MusicItemID(catalogID))
        if let match = try? await libraryRequest.response().items.first {
            return convert(song: match)
        }
        // 2. Try catalog
        let catalogRequest = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(catalogID))
        if let match = try? await catalogRequest.response().items.first {
            return convert(song: match)
        }
        return nil
    }
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
    public static func convert(song: Song) -> LocalTrack { AppleMusicService.convert(song: song) }
    public static func convert(
        track: Track,
        albumTitle: String? = nil,
        albumArtist: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil
    ) -> LocalTrack {
        AppleMusicService.convert(
            track: track,
            albumTitle: albumTitle,
            albumArtist: albumArtist,
            year: year,
            trackNumber: trackNumber
        )
    }
    public static func lookupTrack(catalogID: String) async -> LocalTrack? { await AppleMusicService.lookupTrack(catalogID: catalogID) }

    public func convertSongsToTracks(_ songs: [Song]) -> [LocalTrack] {
        var tracks: [LocalTrack] = []
        var seenIDs = Set<String>()

        for song in songs {
            let rawID = song.id.rawValue
            guard seenIDs.insert(rawID).inserted else { continue }
            tracks.append(Self.convert(song: song))
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
            var allTracksToIngest: [LocalTrack] = []
            var seenTrackIDs = Set<String>()

            func addTrack(_ track: LocalTrack) {
                let key = track.fileURL.standardizedFileURL.path
                if seenTrackIDs.insert(key).inserted {
                    allTracksToIngest.append(track)
                }
            }

            // 1. Fetch songs if requested
            if options.importsSongs {
                importProgress = 0.15
                importStatusText = String(localized: "Scanning songs from Apple Music…")
                let fetchedSongs = try await service.fetchSongs()
                songs = fetchedSongs
                for song in fetchedSongs {
                    addTrack(Self.convert(song: song))
                }
            }

            // 2. Fetch albums if requested
            if options.importsAlbums {
                importProgress = 0.35
                importStatusText = String(localized: "Scanning albums from Apple Music…")
                let fetchedAlbums = try await service.fetchAlbums()
                albums = fetchedAlbums

                let total = fetchedAlbums.count
                for (idx, album) in fetchedAlbums.enumerated() {
                    if idx % 5 == 0 && total > 0 {
                        importProgress = 0.35 + (0.30 * Double(idx) / Double(total))
                        importStatusText = String(localized: "Reading album tracks (\(idx)/\(total))…")
                    }
                    let albumYear = album.releaseDate.map { Calendar.current.component(.year, from: $0) }
                    if let detailed = try? await album.with([.tracks]), let aTracks = detailed.tracks {
                        for (tIdx, t) in aTracks.enumerated() {
                            let tNum: Int? = {
                                if case .song(let s) = t { return s.trackNumber }
                                return tIdx + 1
                            }()
                            let converted = Self.convert(
                                track: t,
                                albumTitle: album.title,
                                albumArtist: album.artistName,
                                year: albumYear,
                                trackNumber: tNum
                            )
                            addTrack(converted)
                        }
                    }
                }
            }

            // 3. Fetch artists if requested
            if options.importsArtists {
                importProgress = 0.70
                importStatusText = String(localized: "Scanning artists from Apple Music…")
                artists = try await service.fetchArtists()
            }

            // 4. Fetch playlists if requested
            if options.importsPlaylists {
                importProgress = 0.80
                importStatusText = String(localized: "Scanning playlists from Apple Music…")
                let fetchedPlaylists = try await service.fetchPlaylists()
                playlists = fetchedPlaylists

                for playlist in playlists {
                    let name = playlist.name
                    guard !name.isEmpty else { continue }
                    var trackIDs: [String] = []
                    if let detailed = try? await playlist.with([.tracks]), let pTracks = detailed.tracks {
                        for t in pTracks {
                            let trackURL = URL(fileURLWithPath: "/AppleMusic/Tracks/\(t.id.rawValue).m4a")
                            trackIDs.append(trackURL.absoluteString)
                            let converted = Self.convert(track: t)
                            addTrack(converted)
                        }
                    }
                    if let playlistStore {
                        _ = await playlistStore.createPlaylist(
                            title: name,
                            description: playlist.curatorName ?? "Apple Music",
                            initialTrackIDs: trackIDs
                        )
                    }
                }
            }

            // 5. Ingest into localStore
            if let localStore, !allTracksToIngest.isEmpty {
                importProgress = 0.92
                importStatusText = String(localized: "Ingesting tracks into MSRU library…")
                try await localStore.addTracks(allTracksToIngest)
                importedTrackCount = allTracksToIngest.count
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
