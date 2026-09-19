//
//  SceneRoutingTests.swift
//  MSRUTests
//

import Foundation
import Testing

@testable import MSRU


@MainActor
struct SceneRoutingTests {

    // MARK: - Route Value

    @Test
    func sceneRouteSupportsCodableRoundTrip()
        throws {

        let original =
            SceneRoute.section(
                .browse
            )


        let data =
            try JSONEncoder()
                .encode(
                    original
                )


        let decoded =
            try JSONDecoder()
                .decode(
                    SceneRoute.self,
                    from:
                        data
                )


        #expect(
            decoded
            ==
            original
        )
    }


    // MARK: - Command

    @Test
    func navigateCommandChangesSemanticRoute() {

        let scene =
            SceneModel(
                application:
                    ApplicationModel()
            )


        scene
            .send(
                .navigate(
                    .section(
                        .library
                    )
                )
            )


        #expect(
            scene
                .navigation
                .route
            ==
            .section(
                .library
            )
        )


        #expect(
            scene
                .navigation
                .section
            ==
            .library
        )
    }


    // MARK: - Isolation

    @Test
    func commandsRemainSceneScoped() {

        let application =
            ApplicationModel()


        let sceneA =
            SceneModel(
                application:
                    application
            )


        let sceneB =
            SceneModel(
                application:
                    application
            )


        sceneA
            .send(
                .navigate(
                    .section(
                        .browse
                    )
                )
            )


        sceneB
            .send(
                .navigate(
                    .section(
                        .settings
                    )
                )
            )


        #expect(
            sceneA
                .navigation
                .route
            ==
            .section(
                .browse
            )
        )


        #expect(
            sceneB
                .navigation
                .route
            ==
            .section(
                .settings
            )
        )
    }


    // MARK: - Restoration

    @Test
    func commandDrivenNavigationFlowsIntoRestoration() {

        let scene =
            SceneModel(
                application:
                    ApplicationModel()
            )


        scene
            .send(
                .navigate(
                    .section(
                        .radio
                    )
                )
            )


        let snapshot =
            scene
                .restorationSnapshot()


        #expect(
            snapshot.section
            ==
            .radio
        )
    }


    @Test
    func restoredSceneExposesSameSemanticRoute()
        throws {

        let application =
            ApplicationModel()


        let original =
            SceneModel(
                application:
                    application
            )


        original
            .send(
                .navigate(
                    .section(
                        .browse
                    )
                )
            )


        let restored =
            try #require(
                SceneModel(
                    application:
                        application,
                    restoration:
                        original
                            .restorationSnapshot()
                )
            )


        #expect(
            restored
                .navigation
                .route
            ==
            .section(
                .browse
            )
        )
    }
}
