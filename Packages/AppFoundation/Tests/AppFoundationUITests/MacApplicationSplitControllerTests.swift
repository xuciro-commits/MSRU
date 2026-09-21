//
//  MacApplicationSplitControllerTests.swift
//  AppFoundationUITests
//

#if os(macOS)

import AppKit
import Testing

@testable import AppFoundationUI


struct MacApplicationSplitControllerTests {

    @Test
    @MainActor
    func installsNavigationAndWorkspaceRegions() {

        let controller =
            makeController()


        controller.loadViewIfNeeded()


        #expect(
            controller
                .splitViewItems
                .count
            ==
            2
        )

        #expect(
            controller
                .navigationItem
                .canCollapse
        )

        #expect(
            !controller
                .workspaceItem
                .canCollapse
        )
    }


    @Test
    @MainActor
    func appliesCompositionTimeStructuralPolicyToSplitItems() {

        let controller =
            MacApplicationSplitController(
                navigationViewController:
                    NSViewController(),
                workspaceViewController:
                    NSViewController(),
                configuration:
                    .init(
                        navigation:
                            .init(
                                canCollapse:
                                    true,
                                minimumThickness:
                                    180
                            ),
                        workspace:
                            .init(
                                canCollapse:
                                    false,
                                minimumThickness:
                                    500,
                                automaticallyAdjustsSafeAreaInsets:
                                    true
                            )
                    )
            )

        controller
            .loadViewIfNeeded()


        #expect(
            controller
                .workspaceItem
                .automaticallyAdjustsSafeAreaInsets
        )

        #expect(
            controller
                .workspaceItem
                .minimumThickness
            ==
            500
        )
    }


    @Test
    @MainActor
    func installsOptionalContextRegion() {

        let controller =
            makeController()


        controller.installContext(
            viewController:
                NSViewController(),
            configuration:
                .init(
                    canCollapse:
                        true,
                    minimumThickness:
                        240,
                    maximumThickness:
                        420
                ),
            isPresented:
                false
        )


        controller.loadViewIfNeeded()


        #expect(
            controller
                .splitViewItems
                .count
            ==
            3
        )

        #expect(
            !controller
                .isContextPresented
        )
    }


    @Test
    @MainActor
    func contextPresentationSynchronizesThroughCallback() {

        let controller =
            makeController()


        controller.installContext(
            viewController:
                NSViewController(),
            configuration:
                .init(
                    canCollapse:
                        true
                ),
            isPresented:
                false
        )


        var observed:
            Bool?


        controller.onContextPresentationChange = {
            value in

            observed =
                value
        }


        controller.setContextPresented(
            true
        )


        #expect(
            controller
                .isContextPresented
        )

        #expect(
            observed
            ==
            true
        )
    }


    // MARK: - Fixture

    @MainActor
    private func makeController()
        -> MacApplicationSplitController {

        MacApplicationSplitController(
            navigationViewController:
                NSViewController(),
            workspaceViewController:
                NSViewController(),
            configuration:
                .init(
                    navigation:
                        .init(
                            canCollapse:
                                true,
                            minimumThickness:
                                180,
                            maximumThickness:
                                280
                        ),
                    workspace:
                        .init(
                            canCollapse:
                                false,
                            minimumThickness:
                                500
                        )
                )
        )
    }
}

#endif
