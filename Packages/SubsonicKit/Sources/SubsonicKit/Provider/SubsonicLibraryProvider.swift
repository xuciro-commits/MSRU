//
//  SubsonicLibraryProvider.swift
//  SubsonicKit
//
//  LibraryProvider implementation bridging SubsonicClient to Unified MediaLibrary.
//

import Foundation
import MediaLibrary

public final class SubsonicLibraryProvider: LibraryProvider, @unchecked Sendable {
    public let sourceID: LibrarySourceID
    public private(set) var source: LibrarySource
    public private(set) var capabilities: LibraryCapabilities

    public let client: SubsonicClient
    private let mapper: SubsonicMapper
    private let probe: SubsonicCapabilityProbe

    public init(
        sourceID: LibrarySourceID,
        sourceName: String,
        serverURL: URL,
        username: String,
        client: SubsonicClient
    ) {
        self.sourceID = sourceID
        self.client = client
        self.mapper = SubsonicMapper(sourceID: sourceID)
        self.probe = SubsonicCapabilityProbe()
        self.capabilities = .fullSubsonic
        self.source = LibrarySource(
            id: sourceID,
            name: sourceName,
            kind: .subsonic,
            capabilities: .fullSubsonic,
            state: .online,
            serverURL: serverURL,
            username: username
        )
    }

    public func probeCapabilities() async throws -> LibraryCapabilities {
        let (_, caps) = try await probe.probe(client: client)
        self.capabilities = caps
        self.source.capabilities = caps
        self.source.state = .online
        return caps
    }

    public func fetchArtists() async throws -> [UnifiedArtist] {
        let dtos = try await client.artists()
        return dtos.map { mapper.mapArtist($0) }
    }

    public func fetchAlbums(artistID: MediaID?) async throws -> [UnifiedAlbum] {
        if let artistID {
            let artistDTO = try await client.artist(id: artistID.rawValue)
            return (artistDTO.album ?? []).map { mapper.mapAlbum($0) }
        } else {
            let albumDTOs = try await client.albumList2(type: "alphabeticalByName", size: 500, offset: 0)
            return albumDTOs.map { mapper.mapAlbum($0) }
        }
    }

    public func fetchTracks(albumID: MediaID?) async throws -> [UnifiedTrack] {
        guard let albumID else { return [] }
        let albumDTO = try await client.album(id: albumID.rawValue)
        return (albumDTO.song ?? []).map { mapper.mapSong($0) }
    }

    public func search(query: String) async throws -> UnifiedSearchResult {
        let result = try await client.search3(query: query)
        let artists = (result.artist ?? []).map { mapper.mapArtist($0) }
        let albums = (result.album ?? []).map { mapper.mapAlbum($0) }
        let tracks = (result.song ?? []).map { mapper.mapSong($0) }
        return UnifiedSearchResult(artists: artists, albums: albums, tracks: tracks)
    }
}
