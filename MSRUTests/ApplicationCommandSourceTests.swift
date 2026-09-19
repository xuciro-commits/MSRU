//
//  ApplicationCommandSourceTests.swift
//  MSRUTests
//

import Foundation
import Testing

@testable import MSRU


struct ApplicationCommandSourceTests {

    // MARK: - Valid URL

    @Test
    func validRouteURLProducesApplicationCommand() {

        let source =
            SceneRouteURLCommandSource(
                scheme:
                    "msru"
            )


        let url =
            URL(
                string:
                    "msru://section/browse"
            )!


        let command =
            source
                .command(
                    from:
                        url
                )


        #expect(
            command
            ==
            .open(
                .section(
                    .browse
                )
            )
        )
    }


    // MARK: - Invalid Representation

    @Test
    func invalidURLProducesNoCommand() {

        let source =
            SceneRouteURLCommandSource(
                scheme:
                    "msru"
            )


        let url =
            URL(
                string:
                    "https://example.com"
            )!


        let command =
            source
                .command(
                    from:
                        url
                )


        #expect(
            command
            ==
            nil
        )
    }


    // MARK: - Target Preservation

    @Test
    func configuredTargetIsPreserved() {

        let source =
            SceneRouteURLCommandSource(
                scheme:
                    "msru",
                target:
                    .new
            )


        let url =
            URL(
                string:
                    "msru://section/library"
            )!


        let command =
            source
                .command(
                    from:
                        url
                )


        #expect(
            command
            ==
            .open(
                .section(
                    .library
                ),
                target:
                    .new
            )
        )
    }


    // MARK: - Explicit Scene Target

    @Test
    func explicitSceneTargetIsPreserved() {

        let sceneID =
            SceneID()


        let source =
            SceneRouteURLCommandSource(
                scheme:
                    "msru",
                target:
                    .scene(
                        sceneID
                    )
            )


        let url =
            URL(
                string:
                    "msru://section/settings"
            )!


        let command =
            source
                .command(
                    from:
                        url
                )


        #expect(
            command
            ==
            .open(
                .section(
                    .settings
                ),
                target:
                    .scene(
                        sceneID
                    )
            )
        )
    }
}
