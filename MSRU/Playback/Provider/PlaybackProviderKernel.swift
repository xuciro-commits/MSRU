//
//  PlaybackProviderKernel.swift
//  MSRU
//

import Foundation


final class PlaybackProviderKernel:
    Sendable {

    let registry:
        ProviderRegistry

    let resolver:
        PlaybackResolver


    init(
        registry:
            ProviderRegistry
    ) {

        self.registry =
            registry

        self.resolver =
            PlaybackResolver(
                registry:
                    registry
            )
    }


    // MARK: - Standard Kernel

    static func standard()
        -> PlaybackProviderKernel {

        let registry =
            ProviderRegistry()


        registry.register(
            LocalPlaybackProvider()
        )


        registry.register(
            OpenversePlaybackProvider()
        )


        return PlaybackProviderKernel(
            registry:
                registry
        )
    }
}
