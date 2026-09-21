//
//  PlaybackResolver.swift
//  MSRU
//

import Foundation


final class PlaybackResolver:
    Sendable {

    let registry:
        ProviderRegistry


    init(
        registry:
            ProviderRegistry
    ) {

        self.registry =
            registry
    }


    func resolve(
        _ request:
            PlaybackRequest
    ) async throws
        -> PlaybackResource {

        /*
         明确指定 Provider 时，
         优先只走指定 Provider。
         */
        if let providerHint =
                request.providerHint,
           let provider =
                registry.provider(
                    for:
                        providerHint
                ),
           provider.canResolve(
                request
           ) {

            do {

                return try await provider
                    .resolve(
                        request
                    )

            } catch {

                throw PlaybackResolutionError
                    .providerFailed(
                        providerID:
                            provider.id,
                        message:
                            error.localizedDescription
                    )
            }
        }


        let candidates =
            registry.candidates(
                for:
                    request
            )


        guard !candidates.isEmpty
        else {

            throw PlaybackResolutionError
                .noProvider(
                    source:
                        request.source,
                    formatHint:
                        request.localFileURL?.pathExtension.uppercased()
                )
        }


        var lastError:
            Error?


        for provider
            in candidates {

            do {

                return try await provider
                    .resolve(
                        request
                    )

            } catch is CancellationError {

                throw CancellationError()

            } catch {

                lastError =
                    error
            }
        }


        if let lastError {

            throw lastError
        }


        throw PlaybackResolutionError
            .noProvider(
                source:
                    request.source,
                formatHint:
                    request.localFileURL?.pathExtension.uppercased()
            )
    }
}


// MARK: - Errors

private enum PlaybackResolutionError:
    LocalizedError {

    case noProvider(
        source:
            PlaybackRequest.Source,
        formatHint:
            String? = nil
    )

    case providerFailed(
        providerID:
            PlaybackProviderID,
        message:
            String
    )


    var errorDescription:
        String? {

        switch self {

        case .noProvider(
            let source,
            let formatHint
        ):
            if let formatHint, !formatHint.isEmpty {
                return "Format .\(formatHint) is currently not supported by playback engine."
            }
            return
                "No playback provider can resolve \(source.rawValue)."


        case .providerFailed(
            let providerID,
            let message
        ):

            return
                "\(providerID.rawValue) playback failed: \(message)"
        }
    }
}
