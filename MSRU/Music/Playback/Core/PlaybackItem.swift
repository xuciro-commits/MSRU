//
//  PlaybackItem.swift
//  MSRU
//

import Foundation


enum PlaybackItemSource:
    String,
    Sendable {

    case local
    case openverse
    case radio
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
    }


    let id:
        String

    let payload:
        Payload


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


        case .openverse, .radio:
            return nil
        }
    }


    var artworkURL:
        URL? {

        switch payload {

        case .local:
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

