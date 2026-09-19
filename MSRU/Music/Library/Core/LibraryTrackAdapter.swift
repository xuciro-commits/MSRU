//
//  LibraryTrackAdapter.swift
//  MSRU
//

import Foundation


// MARK: - LocalTrack

extension LibraryTrack {

    init(
        local track:
            LocalTrack
    ) {

        let source =
            LibraryPlaybackSource(
                kind:
                    .local,
                externalID:
                    String(
                        describing:
                            track.id
                    ),
                localFileURL:
                    track.fileURL
            )


        self.init(
            title:
                track.title,
            artist:
                track.artist,
            album:
                track.album,
            duration:
                track.duration > 0
                ? track.duration
                : nil,
            artworkData:
                track.artworkData,
            sources:
                [
                    source
                ]
        )
    }


    init(
        openverse track:
            OpenverseAudio
    ) {

        let duration:
            TimeInterval?


        if let milliseconds =
                track.durationMilliseconds,
           milliseconds > 0 {

            duration =
                Double(
                    milliseconds
                ) / 1_000

        } else {

            duration =
                nil
        }


        let source =
            LibraryPlaybackSource(
                kind:
                    .openverse,
                externalID:
                    track.id,
                remoteURL:
                    track.mediaURL
            )


        self.init(
            title:
                track.title,
            artist:
                track.creatorTitle,
            duration:
                duration,
            artworkURL:
                track.thumbnailURL,
            sources:
                [
                    source
                ]
        )
    }
}


// MARK: - Source Adapter

extension LibraryPlaybackSource {

    init(
        local track:
            LocalTrack
    ) {

        self.init(
            kind:
                .local,
            externalID:
                String(
                    describing:
                        track.id
                ),
            localFileURL:
                track.fileURL
        )
    }


    init(
        openverse track:
            OpenverseAudio
    ) {

        self.init(
            kind:
                .openverse,
            externalID:
                track.id,
            remoteURL:
                track.mediaURL
        )
    }
}
