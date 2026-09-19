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


    // MARK: - Source

    var source:
        PlaybackItemSource {

        switch payload {

        case .local:
            return .local

        case .openverse:
            return .openverse
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
        }
    }


    var providerLabel:
        String {

        switch payload {

        case .local:
            return "LOCAL"

        case .openverse:
            return "OPENVERSE"
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


        case .openverse:
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
        }
    }
}
