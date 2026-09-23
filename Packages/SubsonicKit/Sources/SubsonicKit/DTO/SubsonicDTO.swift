//
//  SubsonicDTO.swift
//  SubsonicKit
//
//  Data Transfer Objects representing Subsonic and OpenSubsonic wire formats.
//

import Foundation

// MARK: - Root Response Wrapper

public struct SubsonicResponseEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let subsonicResponse: SubsonicResponse<T>

    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

public struct SubsonicResponse<T: Codable & Sendable>: Codable, Sendable {
    public let status: String
    public let version: String
    public let type: String?
    public let serverVersion: String?
    public let openSubsonic: Bool?
    public let error: SubsonicErrorDTO?
    public let data: T?

    public init(
        status: String,
        version: String,
        type: String? = nil,
        serverVersion: String? = nil,
        openSubsonic: Bool? = nil,
        error: SubsonicErrorDTO? = nil,
        data: T? = nil
    ) {
        self.status = status
        self.version = version
        self.type = type
        self.serverVersion = serverVersion
        self.openSubsonic = openSubsonic
        self.error = error
        self.data = data
    }

    public var isSuccess: Bool {
        status.lowercased() == "ok"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        self.status = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: "status")!)
        self.version = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: "version")!)
        self.type = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "type")!)
        self.serverVersion = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "serverVersion")!)
        self.openSubsonic = try container.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys(stringValue: "openSubsonic")!)
        self.error = try container.decodeIfPresent(SubsonicErrorDTO.self, forKey: DynamicCodingKeys(stringValue: "error")!)

        // T is decoded from the same container
        self.data = try? T(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        try container.encode(status, forKey: DynamicCodingKeys(stringValue: "status")!)
        try container.encode(version, forKey: DynamicCodingKeys(stringValue: "version")!)
        try container.encodeIfPresent(type, forKey: DynamicCodingKeys(stringValue: "type")!)
        try container.encodeIfPresent(serverVersion, forKey: DynamicCodingKeys(stringValue: "serverVersion")!)
        try container.encodeIfPresent(openSubsonic, forKey: DynamicCodingKeys(stringValue: "openSubsonic")!)
        try container.encodeIfPresent(error, forKey: DynamicCodingKeys(stringValue: "error")!)
        if let data {
            try data.encode(to: encoder)
        }
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}

public struct EmptyData: Codable, Sendable {
    public init() {}
}

public struct SubsonicErrorDTO: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

// MARK: - OpenSubsonic Extensions

public struct OpenSubsonicExtensionDTO: Codable, Sendable, Hashable {
    public let name: String
    public let versions: [Int]

    public init(name: String, versions: [Int] = [1]) {
        self.name = name
        self.versions = versions
    }
}

public struct OpenSubsonicExtensionsContainer: Codable, Sendable {
    public let openSubsonicExtensions: [OpenSubsonicExtensionDTO]?

    public init(openSubsonicExtensions: [OpenSubsonicExtensionDTO]?) {
        self.openSubsonicExtensions = openSubsonicExtensions
    }
}

// MARK: - Server Info

public struct SubsonicServerInfo: Sendable, Equatable {
    public let apiVersion: String
    public let serverType: String?
    public let serverVersion: String?
    public let isOpenSubsonic: Bool
    public let openSubsonicExtensions: [OpenSubsonicExtensionDTO]

    public init(
        apiVersion: String,
        serverType: String? = nil,
        serverVersion: String? = nil,
        isOpenSubsonic: Bool = false,
        openSubsonicExtensions: [OpenSubsonicExtensionDTO] = []
    ) {
        self.apiVersion = apiVersion
        self.serverType = serverType
        self.serverVersion = serverVersion
        self.isOpenSubsonic = isOpenSubsonic
        self.openSubsonicExtensions = openSubsonicExtensions
    }
}

// MARK: - Artist DTOs

public struct SubsonicArtistDTO: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let coverArt: String?
    public let albumCount: Int?
    public let artistImageUrl: String?
    public let album: [SubsonicAlbumDTO]?

    public init(
        id: String,
        name: String,
        coverArt: String? = nil,
        albumCount: Int? = nil,
        artistImageUrl: String? = nil,
        album: [SubsonicAlbumDTO]? = nil
    ) {
        self.id = id
        self.name = name
        self.coverArt = coverArt
        self.albumCount = albumCount
        self.artistImageUrl = artistImageUrl
        self.album = album
    }
}

public struct SubsonicArtistIndexItemDTO: Codable, Sendable {
    public let name: String
    public let artist: [SubsonicArtistDTO]
}

public struct SubsonicArtistsID3Container: Codable, Sendable {
    public let artists: SubsonicArtistsPayload?

    public struct SubsonicArtistsPayload: Codable, Sendable {
        public let ignoredArticles: String?
        public let index: [SubsonicArtistIndexItemDTO]?
    }
}

public struct SubsonicArtistID3Container: Codable, Sendable {
    public let artist: SubsonicArtistDTO?
}

// MARK: - Album DTOs

public struct SubsonicAlbumDTO: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let title: String?
    public let artist: String?
    public let artistId: String?
    public let coverArt: String?
    public let songCount: Int?
    public let duration: Int?
    public let year: Int?
    public let genre: String?
    public let song: [SubsonicSongDTO]?

    public var effectiveTitle: String {
        title ?? name
    }

    public init(
        id: String,
        name: String,
        title: String? = nil,
        artist: String? = nil,
        artistId: String? = nil,
        coverArt: String? = nil,
        songCount: Int? = nil,
        duration: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        song: [SubsonicSongDTO]? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.coverArt = coverArt
        self.songCount = songCount
        self.duration = duration
        self.year = year
        self.genre = genre
        self.song = song
    }
}

public struct SubsonicAlbumID3Container: Codable, Sendable {
    public let album: SubsonicAlbumDTO?
}

public struct SubsonicAlbumList2Container: Codable, Sendable {
    public let albumList2: SubsonicAlbumListPayload?

    public struct SubsonicAlbumListPayload: Codable, Sendable {
        public let album: [SubsonicAlbumDTO]?
    }
}

// MARK: - Song DTOs

public struct SubsonicSongDTO: Codable, Sendable, Hashable {
    public let id: String
    public let parent: String?
    public let isDir: Bool?
    public let title: String
    public let album: String?
    public let artist: String?
    public let track: Int?
    public let year: Int?
    public let genre: String?
    public let coverArt: String?
    public let size: Int64?
    public let contentType: String?
    public let suffix: String?
    public let duration: Int?
    public let bitRate: Int?
    public let isVideo: Bool?
    public let albumId: String?
    public let artistId: String?
    public let discNumber: Int?

    public init(
        id: String,
        parent: String? = nil,
        isDir: Bool? = false,
        title: String,
        album: String? = nil,
        artist: String? = nil,
        track: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        coverArt: String? = nil,
        size: Int64? = nil,
        contentType: String? = nil,
        suffix: String? = nil,
        duration: Int? = nil,
        bitRate: Int? = nil,
        isVideo: Bool? = nil,
        albumId: String? = nil,
        artistId: String? = nil,
        discNumber: Int? = nil
    ) {
        self.id = id
        self.parent = parent
        self.isDir = isDir
        self.title = title
        self.album = album
        self.artist = artist
        self.track = track
        self.year = year
        self.genre = genre
        self.coverArt = coverArt
        self.size = size
        self.contentType = contentType
        self.suffix = suffix
        self.duration = duration
        self.bitRate = bitRate
        self.isVideo = isVideo
        self.albumId = albumId
        self.artistId = artistId
        self.discNumber = discNumber
    }
}

public struct SubsonicSongContainer: Codable, Sendable {
    public let song: SubsonicSongDTO?
}

// MARK: - Playlist DTOs

public struct SubsonicPlaylistDTO: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let comment: String?
    public let owner: String?
    public let `public`: Bool?
    public let songCount: Int?
    public let duration: Int?
    public let entry: [SubsonicSongDTO]?

    public init(
        id: String,
        name: String,
        comment: String? = nil,
        owner: String? = nil,
        public: Bool? = nil,
        songCount: Int? = nil,
        duration: Int? = nil,
        entry: [SubsonicSongDTO]? = nil
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.owner = owner
        self.public = `public`
        self.songCount = songCount
        self.duration = duration
        self.entry = entry
    }
}

public struct SubsonicPlaylistsContainer: Codable, Sendable {
    public let playlists: SubsonicPlaylistsPayload?

    public struct SubsonicPlaylistsPayload: Codable, Sendable {
        public let playlist: [SubsonicPlaylistDTO]?
    }
}

public struct SubsonicPlaylistContainer: Codable, Sendable {
    public let playlist: SubsonicPlaylistDTO?
}

// MARK: - Search DTOs

public struct SubsonicSearchResult3Payload: Codable, Sendable {
    public let artist: [SubsonicArtistDTO]?
    public let album: [SubsonicAlbumDTO]?
    public let song: [SubsonicSongDTO]?

    public init(
        artist: [SubsonicArtistDTO]? = nil,
        album: [SubsonicAlbumDTO]? = nil,
        song: [SubsonicSongDTO]? = nil
    ) {
        self.artist = artist
        self.album = album
        self.song = song
    }
}

public struct SubsonicSearchResult3Container: Codable, Sendable {
    public let searchResult3: SubsonicSearchResult3Payload?

    public init(searchResult3: SubsonicSearchResult3Payload?) {
        self.searchResult3 = searchResult3
    }
}

// MARK: - OpenSubsonic Lyrics (getLyricsBySongId)

/// A single lyrics line with an optional start time in milliseconds.
public struct SubsonicLyricsLineDTO: Codable, Sendable {
    public let start: Int?
    public let value: String?

    public init(start: Int? = nil, value: String? = nil) {
        self.start = start
        self.value = value
    }
}

/// A lyrics entry (one language / one track).
public struct SubsonicStructuredLyricsDTO: Codable, Sendable {
    public let lang: String?
    public let synced: Bool?
    public let displayArtist: String?
    public let displayTitle: String?
    public let offset: Int?
    public let line: [SubsonicLyricsLineDTO]?

    public init(
        lang: String? = nil,
        synced: Bool? = nil,
        displayArtist: String? = nil,
        displayTitle: String? = nil,
        offset: Int? = nil,
        line: [SubsonicLyricsLineDTO]? = nil
    ) {
        self.lang = lang
        self.synced = synced
        self.displayArtist = displayArtist
        self.displayTitle = displayTitle
        self.offset = offset
        self.line = line
    }

    /// Converts structured lyrics to standard LRC text format.
    public func toLrcText() -> String? {
        guard let lines = line, !lines.isEmpty else { return nil }

        if synced == true {
            // Build synced LRC
            var lrcLines: [String] = []
            if let offset, offset != 0 {
                lrcLines.append("[offset:\(offset)]")
            }
            for l in lines {
                guard let text = l.value, !text.isEmpty else { continue }
                if let startMs = l.start {
                    let totalSeconds = Double(startMs) / 1000.0
                    let minutes = Int(totalSeconds) / 60
                    let seconds = totalSeconds - Double(minutes * 60)
                    lrcLines.append(String(format: "[%02d:%05.2f]%@", minutes, seconds, text))
                } else {
                    lrcLines.append(text)
                }
            }
            return lrcLines.contains(where: { !$0.hasPrefix("[offset:") }) ? lrcLines.joined(separator: "\n") : nil
        } else {
            // Plain lyrics
            let texts = lines.compactMap(\.value).filter { !$0.isEmpty }
            return texts.isEmpty ? nil : texts.joined(separator: "\n")
        }
    }
}

/// Container for the lyricsList response field.
public struct SubsonicLyricsByIdContainer: Codable, Sendable {
    public let lyricsList: SubsonicLyricsListDTO?

    public init(lyricsList: SubsonicLyricsListDTO? = nil) {
        self.lyricsList = lyricsList
    }
}

public struct SubsonicLyricsListDTO: Codable, Sendable {
    public let structuredLyrics: [SubsonicStructuredLyricsDTO]?

    public init(structuredLyrics: [SubsonicStructuredLyricsDTO]? = nil) {
        self.structuredLyrics = structuredLyrics
    }
}
