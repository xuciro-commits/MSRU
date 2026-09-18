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

        request.source
            == .local
        &&
        request.localFileURL
            != nil
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


// MARK: - Errors

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
