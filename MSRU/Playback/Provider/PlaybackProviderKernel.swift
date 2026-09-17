//
//  PlaybackProviderKernel.swift
//  MSRU
//

import Foundation


nonisolated struct PlaybackProviderKernel:
    Sendable {

    let registry:
        ProviderRegistry

    let diagnostics:
        PlaybackDiagnostics

    let resolver:
        PlaybackResolver


    // MARK: - Standard Kernel

    static func standard()
        -> PlaybackProviderKernel {

        let diagnostics =
            PlaybackDiagnostics()


        let registry =
            ProviderRegistry(
                providers: [
                    LocalPlaybackProvider()
                ]
            )


        let resolver =
            PlaybackResolver(
                registry:
                    registry,
                diagnostics:
                    diagnostics
            )


        return PlaybackProviderKernel(
            registry:
                registry,
            diagnostics:
                diagnostics,
            resolver:
                resolver
        )
    }
}
