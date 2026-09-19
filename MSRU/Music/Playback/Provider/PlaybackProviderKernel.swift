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


    static func standard()
        -> PlaybackProviderKernel {

        let registry =
            ProviderRegistry()


        /*
         Extended codecs first.

         DTS currently enters here.
         */

        registry.register(
            ExtendedAudioPlaybackProvider()
        )


        /*
         Apple-native local media.
         */

        registry.register(
            LocalPlaybackProvider()
        )


        /*
         Remote media.
         */

        registry.register(
            OpenversePlaybackProvider()
        )


        return PlaybackProviderKernel(
            registry:
                registry
        )
    }
}
