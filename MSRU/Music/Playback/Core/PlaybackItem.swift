//
//  PlaybackItem.swift
//  MSRU
//

import Foundation
import MediaLibrary


enum PlaybackItemSource:
    String,
    Sendable {

    case local
    case openverse
    case radio
    case subsonic
}


struct PlaybackItem:
    Identifiable {

    enum Payload {

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


    let id:
        String

    let payload:
        Payload

    /// Server identity for remote lyrics and other song-ID scoped requests.
    let subsonicServerID: String?


    // MARK: - Local

    init(
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

    init(
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

    init(
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

    init(
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

    static func subsonic(
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

    var subsonicPayload: (itemID: String, title: String, artist: String, album: String?)? {
        guard case .subsonic(let id, let title, let artist, let album, _, _, _) = payload else {
            return nil
        }
        return (itemID: id, title: title, artist: artist, album: album)
    }

    /// Album name from any payload type.
    var album: String? {
        switch payload {
        case .local(let track): return track.album
        case .subsonic(_, _, _, let album, _, _, _): return album
        case .openverse, .radio: return nil
        }
    }

    /// Subsonic remote song ID, nil for non-Subsonic sources.
    var subsonicSongID: String? {
        guard case .subsonic(let id, _, _, _, _, _, _) = payload else {
            return nil
        }
        return id
    }


    // MARK: - TrackRowSummary

    init(summary: TrackRowSummary) {
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

    var source:
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

    var title:
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


    var subtitle:
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


    var providerLabel:
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

    var artworkData:
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


    var artworkURL:
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

    var artworkImageReference: MediaImageReference? {
        switch payload {
        case .local(let track):
            return track.artworkReference.map { MediaImageReference(relativePath: $0) }
        case .openverse(let track):
            return track.thumbnailURL.map { MediaImageReference(url: $0) }
        case .radio(let station):
            return station.artworkURL.map { MediaImageReference(url: $0) }
        case .subsonic(_, _, _, _, _, let artworkReference, _):
            return artworkReference.flatMap { MediaImageReference(string: $0) }
        }
    }


    // MARK: - Duration

    var duration:
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

    var localTrack:
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


    var openverseTrack:
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


    var radioStation:
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

    var playbackRequest:
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

// MARK: - Library Item Initializer

extension PlaybackItem {
    /// Saved records retain provider identities. Unsupported future sources are
    /// skipped rather than mislabeled as an existing provider.
    init?(library track: LibraryTrack) {
        for source in track.sources {
            switch source.kind {
            case .local:
                guard let url = source.localFileURL, url.isFileURL else { continue }
                self.init(local: LocalTrack(fileURL: url, title: track.title, artist: track.artist,
                    album: track.album, duration: track.duration ?? 0, artworkData: track.artworkData))
                return
            case .openverse:
                guard let url = source.remoteURL,
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { continue }
                self.init(openverse: OpenverseAudio(
                    id: source.externalID ?? url.absoluteString, title: track.title, creator: track.artist,
                    mediaURLString: url.absoluteString, thumbnailURLString: track.artworkURL?.absoluteString,
                    durationMilliseconds: track.duration.flatMap { Int(exactly: ($0 * 1_000).rounded()) },
                    source: "openverse"))
                return
            case .jamendo, .appleMusic, .openSubsonic:
                continue
            }
        }
        return nil
    }
}

// MARK: - Audio Format Info

struct AudioFormatInfo: Equatable, Sendable {
    let codec: String
    let sampleRate: String?
    let bitDepth: String?
    let bitrate: String?
    let isLossless: Bool
    let isHiRes: Bool

    var summaryText: String {
        var parts: [String] = [codec]
        if let bitrate {
            parts.append(bitrate)
        }
        if let sampleRate {
            parts.append(sampleRate)
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Track Playback State

nonisolated enum TrackPlaybackState: Equatable, Sendable {
    case idle
    case resolving
    case playing
    case paused
    case failed(String)

    var isResolving: Bool {
        if case .resolving = self { return true }
        return false
    }

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
