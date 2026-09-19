//
//  LocalPlaybackProvider.swift
//  MSRU
//

import Foundation


struct LocalPlaybackProvider:
    PlaybackProvider {

    let id:
        PlaybackProviderID =
            .local


    let priority =
        1_000


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


        /*
         Apple 原生不支持的格式
         不应该继续冒充 Native Local。
         */

        guard
            !ExtendedAudioFormatSupport
                .supports(
                    url
                )
        else {

            return false
        }


        return true
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

            throw LocalPlaybackProviderError
                .missingFileURL
        }


        guard
            url.isFileURL
        else {

            throw LocalPlaybackProviderError
                .invalidFileURL
        }


        guard
            FileManager
                .default
                .fileExists(
                    atPath:
                        url.path
                )
        else {

            throw LocalPlaybackProviderError
                .fileNotFound(
                    url
                )
        }


        return PlaybackResource(

            providerID:
                .local,

            transport:
                .avPlayerURL(
                    url
                )
        )
    }
}


private enum LocalPlaybackProviderError:
    LocalizedError {

    case missingFileURL

    case invalidFileURL

    case fileNotFound(
        URL
    )


    var errorDescription:
        String? {

        switch self {

        case .missingFileURL:

            return
                "The local track has no file URL."


        case .invalidFileURL:

            return
                "The local playback URL is not a file URL."


        case .fileNotFound(
            let url
        ):

            return
                "Local audio file was not found: \(url.lastPathComponent)"
        }
    }
}
