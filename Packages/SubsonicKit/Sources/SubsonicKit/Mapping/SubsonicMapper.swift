//
//  SubsonicMapper.swift
//  SubsonicKit
//
//  Translates Subsonic/OpenSubsonic wire DTOs into clean MediaLibrary domain models.
//

import Foundation
import MediaLibrary

public struct SubsonicMapper: Sendable {
    public let sourceID: LibrarySourceID

    public init(sourceID: LibrarySourceID) {
        self.sourceID = sourceID
    }

    public func mapArtist(_ dto: SubsonicArtistDTO) -> UnifiedArtist {
        UnifiedArtist(
            id: MediaID(sourceID: sourceID, rawValue: dto.id),
            name: dto.name,
            albumCount: dto.albumCount ?? dto.album?.count ?? 0,
            trackCount: 0,
            artworkReference: dto.coverArt
        )
    }

    public func mapAlbum(_ dto: SubsonicAlbumDTO) -> UnifiedAlbum {
        let artistID: MediaID? = dto.artistId.map { MediaID(sourceID: sourceID, rawValue: $0) }
        return UnifiedAlbum(
            id: MediaID(sourceID: sourceID, rawValue: dto.id),
            title: dto.effectiveTitle,
            artist: dto.artist ?? "Unknown Artist",
            artistID: artistID,
            year: dto.year,
            genre: dto.genre,
            trackCount: dto.songCount ?? dto.song?.count ?? 0,
            duration: TimeInterval(dto.duration ?? 0),
            artworkReference: dto.coverArt
        )
    }

    public func mapSong(_ dto: SubsonicSongDTO) -> UnifiedTrack {
        let albumID: MediaID? = dto.albumId.map { MediaID(sourceID: sourceID, rawValue: $0) }
        let artistID: MediaID? = dto.artistId.map { MediaID(sourceID: sourceID, rawValue: $0) }

        return UnifiedTrack(
            id: MediaID(sourceID: sourceID, rawValue: dto.id),
            title: dto.title,
            artist: dto.artist ?? "Unknown Artist",
            artistID: artistID,
            album: dto.album,
            albumID: albumID,
            trackNumber: dto.track,
            discNumber: dto.discNumber,
            year: dto.year,
            genre: dto.genre,
            duration: TimeInterval(dto.duration ?? 0),
            bitrateKbps: dto.bitRate,
            codec: dto.suffix?.uppercased(),
            artworkReference: dto.coverArt,
            isFavorite: false,
            playCount: 0,
            dateAdded: Date()
        )
    }

    public func mapPlaylist(_ dto: SubsonicPlaylistDTO) -> UnifiedPlaylist {
        UnifiedPlaylist(
            id: MediaID(sourceID: sourceID, rawValue: dto.id),
            name: dto.name,
            comment: dto.comment,
            trackCount: dto.songCount ?? dto.entry?.count ?? 0,
            duration: TimeInterval(dto.duration ?? 0),
            isReadOnly: false
        )
    }
}
