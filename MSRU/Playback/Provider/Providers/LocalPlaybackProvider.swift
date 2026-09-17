//
//  LocalPlaybackProvider.swift
//  MSRU
//

import Foundation


nonisolated struct LocalPlaybackProvider:
    PlaybackProvider {

    // MARK: - Descriptor

    let descriptor =
        PlaybackProviderDescriptor(
            id:
                .local,
            displayName:
                "Local",
            capabilities: [
                .playback,
                .localFile
            ],
            supportedQualities: [
                .original
            ]
        )


    // MARK: - Health

    func healthCheck()
        async
        -> ProviderHealth {

        await .available
    }


    // MARK: - Capability

    func canResolve(
        _ request:
            PlaybackRequest
    ) async -> Bool {

        guard
            let url =
                request
                    .localFileURL
        else {
            return false
        }


        return url.isFileURL
    }


    // MARK: - Resolve

    func resolve(
        _ request:
            PlaybackRequest
    ) async throws
        -> PlaybackResource {

        guard
            let url =
                request
                    .localFileURL
        else {

            throw PlaybackProviderError
                .unsupportedRequest(
                    providerID:
                        .local
                )
        }


        guard url.isFileURL else {

            throw PlaybackProviderError
                .unsupportedRequest(
                    providerID:
                        .local
                )
        }


        var isDirectory:
            ObjCBool = false


        let exists =
            FileManager
                .default
                .fileExists(
                    atPath:
                        url.path,
                    isDirectory:
                        &isDirectory
                )


        guard
            exists,
            !isDirectory.boolValue
        else {

            throw PlaybackProviderError
                .fileMissing(
                    url
                )
        }


        return await PlaybackResource(
            providerID:
                .local,
            transport:
                .avPlayerURL(
                    url
                ),
            quality:
                .original
        )
    }
}
