//
//  SceneRouteURLCommandSource.swift
//  MSRU
//

import Foundation


// MARK: - Scene Route URL Command Source

nonisolated struct SceneRouteURLCommandSource:
    ApplicationCommandSource,
    Sendable {

    typealias Input =
        URL


    // MARK: - Codec

    private let codec:
        SceneRouteURLCodec


    // MARK: - Target

    private let target:
        SceneRoutingTarget


    // MARK: - Init

    init(
        codec:
            SceneRouteURLCodec,
        target:
            SceneRoutingTarget =
                .activeOrNew
    ) {

        self.codec =
            codec


        self.target =
            target
    }


    init(
        scheme:
            String,
        target:
            SceneRoutingTarget =
                .activeOrNew
    ) {

        self.codec =
            SceneRouteURLCodec(
                scheme:
                    scheme
            )


        self.target =
            target
    }


    // MARK: - Command

    func command(
        from url:
            URL
    ) -> ApplicationCommand? {

        guard
            let route =
                codec
                    .decode(
                        url
                    )
        else {

            return nil
        }


        return
            .open(
                route,
                target:
                    target
            )
    }
}
