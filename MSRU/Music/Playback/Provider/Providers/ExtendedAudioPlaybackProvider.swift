//
//  ExtendedAudioPlaybackProvider.swift
//  MSRU
//

import Foundation


struct ExtendedAudioPlaybackProvider:
    PlaybackProvider {

    let id:
        PlaybackProviderID =
            .extendedAudio


    let priority =
        2_000


    private let codec:
        any AudioCodecBackend


    init(
        codec:
            any AudioCodecBackend =
                FFmpegCodecBackend()
    ) {

        self.codec =
            codec
    }


    func canResolve(
        _ request:
            PlaybackRequest
    ) -> Bool {

        guard
            request.source
                == .local,
            let url =
                request.localFileURL
        else {

            return false
        }


        return codec
            .canDecode(
                url
            )
    }


    func resolve(
        _ request:
            PlaybackRequest
    ) async throws
        -> PlaybackResource {

        try Task
            .checkCancellation()


        guard
            let url =
                request.localFileURL
        else {

            throw ExtendedAudioPlaybackError
                .missingFile
        }


        let decoded =
            try await codec
                .open(
                    url
                )


        return PlaybackResource(

            providerID:
                .extendedAudio,

            transport:
                .decodedPCM(
                    PCMPlaybackResource(
                        format:
                            decoded.format,
                        session:
                            decoded.session
                    )
                ),

            duration:
                decoded
                    .format
                    .duration
        )
    }
}


private enum ExtendedAudioPlaybackError:
    LocalizedError {

    case missingFile


    var errorDescription:
        String? {

        "Extended audio source file is missing."
    }
}
