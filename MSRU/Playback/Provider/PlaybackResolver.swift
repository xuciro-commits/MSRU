//
//  PlaybackResolver.swift
//  MSRU
//

import Foundation


actor PlaybackResolver {

    private let registry:
        ProviderRegistry

    private let diagnostics:
        PlaybackDiagnostics


    init(
        registry:
            ProviderRegistry,
        diagnostics:
            PlaybackDiagnostics
    ) {

        self.registry =
            registry

        self.diagnostics =
            diagnostics
    }


    // MARK: - Resolve

    func resolve(
        _ request:
            PlaybackRequest
    ) async throws
        -> PlaybackResource {

        let providers =
            await registry
                .orderedProviders(
                    preferred:
                        request
                            .preferredProviderID
                )


        var lastError:
            PlaybackProviderError?


        for provider in providers {

            try Task
                .checkCancellation()


            let descriptor =
            provider
                    .descriptor


            let providerID =
                descriptor
                    .id


            // MARK: Health

            let health =
                await provider
                    .healthCheck()


            switch health.status {

            case .unavailable:

                let error =
                    PlaybackProviderError
                        .resourceUnavailable(
                            providerID:
                                providerID,
                            reason:
                                health.message
                        )


                lastError =
                    error


                await recordSkipped(
                    request:
                        request,
                    providerID:
                        providerID,
                    message:
                        error.localizedDescription
                )


                continue


            case .authenticationRequired:

                let error =
                    PlaybackProviderError
                        .authenticationRequired(
                            providerID:
                                providerID
                        )


                lastError =
                    error


                await recordSkipped(
                    request:
                        request,
                    providerID:
                        providerID,
                    message:
                        health.message
                        ?? error.localizedDescription
                )


                continue


            case .available,
                 .degraded:

                break
            }


            // MARK: Capability Check

            let canResolve =
                await provider
                    .canResolve(
                        request
                    )


            guard canResolve else {

                await recordSkipped(
                    request:
                        request,
                    providerID:
                        providerID,
                    message:
                        "Provider cannot resolve this request."
                )


                continue
            }


            // MARK: Resolve

            let startedAt =
                Date()


            do {

                let resource =
                    try await provider
                        .resolve(
                            request
                        )


                try Task
                    .checkCancellation()


                let latency =
                    Date()
                        .timeIntervalSince(
                            startedAt
                        )
                    * 1000


                await diagnostics
                    .record(
                        PlaybackDiagnosticEvent(
                            requestID:
                                request.requestID,
                            trackID:
                                request.trackID,
                            providerID:
                                providerID,
                            outcome:
                                .succeeded,
                            latencyMilliseconds:
                                latency,
                            message:
                                "Resolved."
                        )
                    )


                #if DEBUG

                print(
                    "Provider Resolve ✓",
                    "[\(providerID.rawValue)]",
                    "\(Int(latency)) ms"
                )

                #endif


                return resource

            } catch is CancellationError {

                throw CancellationError()

            } catch {

                let normalizedError:
                    PlaybackProviderError


                if let providerError =
                    error
                    as? PlaybackProviderError {

                    normalizedError =
                        providerError

                } else {

                    normalizedError =
                        .providerFailure(
                            providerID:
                                providerID,
                            message:
                                error.localizedDescription
                        )
                }


                lastError =
                    normalizedError


                let latency =
                    Date()
                        .timeIntervalSince(
                            startedAt
                        )
                    * 1000


                await diagnostics
                    .record(
                        PlaybackDiagnosticEvent(
                            requestID:
                                request.requestID,
                            trackID:
                                request.trackID,
                            providerID:
                                providerID,
                            outcome:
                                .failed,
                            latencyMilliseconds:
                                latency,
                            message:
                                normalizedError
                                    .localizedDescription
                        )
                    )


                #if DEBUG

                print(
                    "Provider Resolve ✕",
                    "[\(providerID.rawValue)]",
                    normalizedError
                        .localizedDescription
                )

                #endif
            }
        }


        // MARK: - All Failed

        let finalError =
            lastError
            ?? PlaybackProviderError
                .noProviderAvailable(
                    trackID:
                        request.trackID
                )


        await diagnostics
            .record(
                PlaybackDiagnosticEvent(
                    requestID:
                        request.requestID,
                    trackID:
                        request.trackID,
                    providerID:
                        nil,
                    outcome:
                        .resolveFailed,
                    message:
                        finalError
                            .localizedDescription
                )
            )


        throw finalError
    }


    // MARK: - Diagnostics Helpers

    private func recordSkipped(
        request:
            PlaybackRequest,
        providerID:
            PlaybackProviderID,
        message:
            String
    ) async {

        await diagnostics
            .record(
                PlaybackDiagnosticEvent(
                    requestID:
                        request.requestID,
                    trackID:
                        request.trackID,
                    providerID:
                        providerID,
                    outcome:
                        .skipped,
                    message:
                        message
                )
            )
    }
}
