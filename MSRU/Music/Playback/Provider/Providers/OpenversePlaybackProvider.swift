//
//  OpenversePlaybackProvider.swift
//  MSRU
//

import Foundation


struct OpenversePlaybackProvider:
    PlaybackProvider {

    let id:
        PlaybackProviderID =
        .openverse


    let priority =
        900


    func canResolve(
        _ request:
            PlaybackRequest
    ) -> Bool {

        request.source
            == .openverse
        &&
        request.remoteURL
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
                request.remoteURL
        else {

            throw OpenversePlaybackProviderError
                .missingURL
        }


        guard
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "https"
            || scheme == "http"
        else {

            throw OpenversePlaybackProviderError
                .invalidURL
        }


        /*
         现在 Openverse 的 media URL
         已经是可直接交给 AVPlayer 的资源。

         将来如果 Openverse URL
         需要 refresh / redirect / auth，
         逻辑只需要改这个 Provider，
         PlaybackController 完全不用动。
         */
        return PlaybackResource(
            providerID:
                .openverse,
            transport:
                .avPlayerURL(
                    url
                )
        )
    }
}


// MARK: - Errors

private enum OpenversePlaybackProviderError:
    LocalizedError {

    case missingURL
    case invalidURL


    var errorDescription:
        String? {

        switch self {

        case .missingURL:

            return
                "Openverse returned no playable audio URL."


        case .invalidURL:

            return
                "Openverse returned an invalid audio URL."
        }
    }
}
