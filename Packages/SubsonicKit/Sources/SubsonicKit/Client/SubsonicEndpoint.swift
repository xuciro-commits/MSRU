//
//  SubsonicEndpoint.swift
//  SubsonicKit
//
//  REST API endpoint definitions for Subsonic and OpenSubsonic.
//

import Foundation

public enum SubsonicEndpoint: Sendable {
    case ping
    case getOpenSubsonicExtensions
    case getArtists
    case getArtist(id: String)
    case getAlbum(id: String)
    case getSong(id: String)
    case getAlbumList2(type: String, size: Int, offset: Int)
    case getCoverArt(id: String, size: Int?)
    case stream(id: String, format: String?, maxBitRate: Int?)
    case search3(query: String, artistCount: Int, albumCount: Int, songCount: Int)
    case getPlaylists
    case getPlaylist(id: String)
    case star(id: String?, albumId: String?, artistId: String?)
    case unstar(id: String?, albumId: String?, artistId: String?)
    case scrobble(id: String, time: Double?, submission: Bool)
    case getLyricsBySongId(id: String)

    public var path: String {
        switch self {
        case .ping: return "ping.view"
        case .getOpenSubsonicExtensions: return "getOpenSubsonicExtensions.view"
        case .getArtists: return "getArtists.view"
        case .getArtist: return "getArtist.view"
        case .getAlbum: return "getAlbum.view"
        case .getSong: return "getSong.view"
        case .getAlbumList2: return "getAlbumList2.view"
        case .getCoverArt: return "getCoverArt.view"
        case .stream: return "stream.view"
        case .search3: return "search3.view"
        case .getPlaylists: return "getPlaylists.view"
        case .getPlaylist: return "getPlaylist.view"
        case .star: return "star.view"
        case .unstar: return "unstar.view"
        case .scrobble: return "scrobble.view"
        case .getLyricsBySongId: return "getLyricsBySongId.view"
        }
    }

    public var requiresAuthentication: Bool {
        switch self {
        case .getOpenSubsonicExtensions:
            return false
        default:
            return true
        }
    }

    public var queryItems: [URLQueryItem] {
        switch self {
        case .ping, .getOpenSubsonicExtensions, .getArtists, .getPlaylists:
            return []

        case .getArtist(let id):
            return [URLQueryItem(name: "id", value: id)]

        case .getAlbum(let id):
            return [URLQueryItem(name: "id", value: id)]

        case .getSong(let id):
            return [URLQueryItem(name: "id", value: id)]

        case .getAlbumList2(let type, let size, let offset):
            return [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "size", value: "\(size)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]

        case .getCoverArt(let id, let size):
            var items = [URLQueryItem(name: "id", value: id)]
            if let size {
                items.append(URLQueryItem(name: "size", value: "\(size)"))
            }
            return items

        case .stream(let id, let format, let maxBitRate):
            var items = [URLQueryItem(name: "id", value: id)]
            if let format {
                items.append(URLQueryItem(name: "format", value: format))
            }
            if let maxBitRate {
                items.append(URLQueryItem(name: "maxBitRate", value: "\(maxBitRate)"))
            }
            return items

        case .search3(let query, let artistCount, let albumCount, let songCount):
            return [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "artistCount", value: "\(artistCount)"),
                URLQueryItem(name: "albumCount", value: "\(albumCount)"),
                URLQueryItem(name: "songCount", value: "\(songCount)")
            ]

        case .getPlaylist(let id):
            return [URLQueryItem(name: "id", value: id)]

        case .star(let id, let albumId, let artistId):
            var items: [URLQueryItem] = []
            if let id { items.append(URLQueryItem(name: "id", value: id)) }
            if let albumId { items.append(URLQueryItem(name: "albumId", value: albumId)) }
            if let artistId { items.append(URLQueryItem(name: "artistId", value: artistId)) }
            return items

        case .unstar(let id, let albumId, let artistId):
            var items: [URLQueryItem] = []
            if let id { items.append(URLQueryItem(name: "id", value: id)) }
            if let albumId { items.append(URLQueryItem(name: "albumId", value: albumId)) }
            if let artistId { items.append(URLQueryItem(name: "artistId", value: artistId)) }
            return items

        case .scrobble(let id, let time, let submission):
            var items = [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "submission", value: submission ? "true" : "false")
            ]
            if let time {
                items.append(URLQueryItem(name: "time", value: "\(Int64(time * 1000))"))
            }
            return items

        case .getLyricsBySongId(let id):
            return [URLQueryItem(name: "id", value: id)]
        }
    }
}
