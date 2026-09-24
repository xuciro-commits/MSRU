//
//  PlaybackItem.swift
//  MSRU
//

import Foundation
import MusicDomain
import MusicLibrary
import SubsonicKit


public enum PlaybackItemSource:
    String,
    Sendable {

    case local
    case openverse
    case radio
    case subsonic
}


public struct PlaybackItem:
    Identifiable {

    public enum Payload {

        case local(
            LocalTrack
        )

        case openverse(
            OpenverseAudio
        )

        case radio(
            RadioStation
        )

        case subsonic(
            id: String,
            title: String,
            artist: String,
            album: String?,
            duration: TimeInterval,
            artworkReference: String?,
            streamURL: URL? = nil
        )
    }


    public let id:
        String

    public let payload:
        Payload

    /// Server identity for remote lyrics and other song-ID scoped requests.
    public let subsonicServerID: String?


    // MARK: - Local

    public init(
        local track:
            LocalTrack
    ) {

        self.id =
            "local:\(track.id)"

        self.payload =
            .local(
                track
            )
        self.subsonicServerID = nil
    }


    // MARK: - Openverse

    public init(
        openverse track:
            OpenverseAudio
    ) {

        self.id =
            "openverse:\(track.id)"

        self.payload =
            .openverse(
                track
            )
        self.subsonicServerID = nil
    }


    // MARK: - Radio

    public init(
        radio station:
            RadioStation
    ) {

        self.id =
            "radio:\(station.id)"

        self.payload =
            .radio(
                station
            )
        self.subsonicServerID = nil
    }


    // MARK: - Subsonic

    public init(
        subsonic id: String,
        serverID: LibrarySourceID? = nil,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkReference: String? = nil,
        streamURL: URL? = nil
    ) {
        self.id = serverID.map { "subsonic:\($0.rawValue):\(id)" } ?? "subsonic:\(id)"
        self.subsonicServerID = serverID?.rawValue
        self.payload = .subsonic(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkReference: artworkReference,
            streamURL: streamURL
        )
    }

    public static func subsonic(
        serverID: LibrarySourceID? = nil,
        itemID: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        streamURL: URL? = nil,
        coverArtURL: URL? = nil
    ) -> PlaybackItem {
        PlaybackItem(
            subsonic: itemID,
            serverID: serverID,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkReference: coverArtURL?.absoluteString,
            streamURL: streamURL
        )
    }

    public var subsonicPayload: (itemID: String, title: String, artist: String, album: String?)? {
        guard case .subsonic(let id, let title, let artist, let album, _, _, _) = payload else {
            return nil
        }
        return (itemID: id, title: title, artist: artist, album: album)
    }

    /// Album name from any payload type.
    public var album: String? {
        switch payload {
        case .local(let track): return track.album
        case .subsonic(_, _, _, let album, _, _, _): return album
        case .openverse, .radio: return nil
        }
    }

    /// Subsonic remote song ID, nil for non-Subsonic sources.
    public var subsonicSongID: String? {
        guard case .subsonic(let id, _, _, _, _, _, _) = payload else {
            return nil
        }
        return id
    }


    // MARK: - TrackRowSummary

    public init(summary: TrackRowSummary) {
        if summary.sourceID == "local" || summary.sourceID == nil {
            self.init(
                local: LocalTrack(
                    fileURL: URL(fileURLWithPath: summary.id),
                    title: summary.title,
                    artist: summary.artist,
                    album: summary.album,
                    duration: summary.duration,
                    artworkReference: summary.artworkReference
                )
            )
        } else {
            self.init(
                subsonic: summary.id,
                serverID: summary.sourceID.map {
                    LibrarySourceID($0.hasPrefix("src_") ? String($0.dropFirst(4)) : $0)
                },
                title: summary.title,
                artist: summary.artist,
                album: summary.album,
                duration: summary.duration,
                artworkReference: summary.artworkReference
            )
        }
    }


    // MARK: - Source

    public var source:
        PlaybackItemSource {

        switch payload {

        case .local:
            return .local

        case .openverse:
            return .openverse

        case .radio:
            return .radio

        case .subsonic:
            return .subsonic
        }
    }


    // MARK: - Metadata

    public var title:
        String {

        switch payload {

        case .local(
            let track
        ):

            return track.title


        case .openverse(
            let track
        ):

            return track.title


        case .radio(
            let station
        ):

            return station.name

        case .subsonic(_, let title, _, _, _, _, _):
            return title
        }
    }


    public var subtitle:
        String {

        switch payload {

        case .local(
            let track
        ):

            return track.artist


        case .openverse(
            let track
        ):

            return track.creatorTitle


        case .radio(
            let station
        ):

            return "\(station.genre.rawValue) • \(station.country)"

        case .subsonic(_, _, let artist, _, _, _, _):
            return artist
        }
    }


    public var providerLabel:
        String {

        switch payload {

        case .local:
            return "LOCAL"

        case .openverse:
            return "OPENVERSE"

        case .radio:
            return "LIVE RADIO"

        case .subsonic:
            return "SUBSONIC"
        }
    }


    // MARK: - Artwork

    public var artworkData:
        Data? {

        switch payload {

        case .local(
            let track
        ):

            return track.artworkData


        case .openverse, .radio, .subsonic:
            return nil
        }
    }


    public var artworkURL:
        URL? {

        switch payload {

        case .local:
            return nil

        case .subsonic(_, _, _, _, _, let artworkReference, _):
            if let artworkReference, let url = URL(string: artworkReference), url.scheme?.hasPrefix("http") == true {
                return url
            }
            return nil

        case .openverse(
            let track
        ):

            return track.thumbnailURL


        case .radio(
            let station
        ):

            return station.artworkURL
        }
    }

    public var artworkReference: String? {
        switch payload {
        case .local(let track):
            return track.artworkReference
        case .subsonic(_, _, _, _, _, let ref, _):
            return ref
        case .openverse(let track):
            return track.thumbnailURL?.absoluteString
        case .radio(let station):
            return station.artworkURL?.absoluteString
        }
    }

    // MARK: - Duration

    public var duration:
        TimeInterval? {

        switch payload {

        case .local(
            let track
        ):

            guard
                track.duration > 0
            else {

                return nil
            }


            return track.duration


        case .openverse(
            let track
        ):

            guard
                let milliseconds =
                    track.durationMilliseconds,
                milliseconds > 0
            else {

                return nil
            }


            return
                Double(
                    milliseconds
                )
                / 1000


        case .radio:
            return nil

        case .subsonic(_, _, _, _, let duration, _, _):
            return duration > 0 ? duration : nil
        }
    }


    // MARK: - Typed Payload

    public var localTrack:
        LocalTrack? {

        guard
            case .local(
                let track
            ) = payload
        else {

            return nil
        }


        return track
    }


    public var openverseTrack:
        OpenverseAudio? {

        guard
            case .openverse(
                let track
            ) = payload
        else {

            return nil
        }


        return track
    }


    public var radioStation:
        RadioStation? {

        guard
            case .radio(
                let station
            ) = payload
        else {

            return nil
        }


        return station
    }


    // MARK: - Playback Request

    public var playbackRequest:
        PlaybackRequest {

        switch payload {

        case .local(
            let track
        ):
            if !track.fileURL.isFileURL,
               let scheme = track.fileURL.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return PlaybackRequest(
                    itemID: track.id,
                    source: .subsonic,
                    preferredQuality: .automatic,
                    localFileURL: nil,
                    remoteURL: track.fileURL,
                    providerHint: .subsonic
                )
            }

            return PlaybackRequest(
                itemID:
                    id,
                source:
                    .local,
                preferredQuality:
                    .automatic,
                localFileURL:
                    track.fileURL,
                remoteURL:
                    nil,
                providerHint:
                    .local
            )


        case .openverse(
            let track
        ):

            return PlaybackRequest(
                itemID:
                    id,
                source:
                    .openverse,
                preferredQuality:
                    .automatic,
                localFileURL:
                    nil,
                remoteURL:
                    track.mediaURL,
                providerHint:
                    .openverse
            )


        case .radio(
            let station
        ):

            return PlaybackRequest(
                itemID:
                    id,
                source:
                    .radio,
                preferredQuality:
                    .automatic,
                localFileURL:
                    nil,
                remoteURL: station.streamURL,
                providerHint: .radio
            )

        case .subsonic(let subsonicID, _, _, _, _, _, let streamURL):
            return PlaybackRequest(
                itemID: subsonicID,
                source: .subsonic,
                preferredQuality: .automatic,
                localFileURL: nil,
                remoteURL: streamURL,
                subsonicServerID: subsonicServerID,
                providerHint: .subsonic
            )
        }
    }
}

// MARK: - Audio Format Info

public struct AudioFormatInfo: Equatable, Sendable {
    public let codec: String
    public let sampleRate: String?
    public let bitDepth: String?
    public let bitrate: String?
    public let isLossless: Bool
    public let isHiRes: Bool

    public var summaryText: String {
        var parts: [String] = [codec]
        if let bitrate {
            parts.append(bitrate)
        }
        if let sampleRate {
            parts.append(sampleRate)
        }
        return parts.joined(separator: " • ")
    }

    nonisolated public init(
        codec: String,
        sampleRate: String?,
        bitDepth: String?,
        bitrate: String?,
        isLossless: Bool,
        isHiRes: Bool
    ) {
        self.codec = codec
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitrate = bitrate
        self.isLossless = isLossless
        self.isHiRes = isHiRes
    }
}

// MARK: - Track Playback State

public nonisolated enum TrackPlaybackState: Equatable, Sendable {
    case idle
    case resolving
    case playing
    case paused
    case failed(String)

    public var isResolving: Bool {
        if case .resolving = self { return true }
        return false
    }

    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
