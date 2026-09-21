//
//  SceneRoutingTests.swift
//  MSRUTests
//

import Foundation
import Testing
import AppFoundation

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

@Suite("Compact Navigation & Platform Shell Tests")
struct CompactNavigationTests {

    @Test("All CompactNavigationTabs have valid title and system image")
    @MainActor
    func testCompactTabsProperties() {
        for tab in CompactNavigationTab.allCases {
            #expect(!tab.systemImage.isEmpty)
            #expect(!tab.id.isEmpty)
        }
        #expect(CompactNavigationTab.allCases.count == 4)
    }

    @Test("SceneModel navigates and preserves scene identity across compact commands")
    @MainActor
    func testSceneNavigationAcrossCompactTabs() {
        let scene = MSRUPreviewData.makeScene()

        scene.send(.navigate(.section(.radio)))
        #expect(scene.navigation.section == .radio)

        scene.send(.navigate(.section(.albums)))
        #expect(scene.navigation.section == .albums)

        scene.send(.navigate(.section(.importReview)))
        #expect(scene.navigation.section == .importReview)

        scene.send(.navigate(.section(.settings)))
        #expect(scene.navigation.section == .settings)
    }
}
