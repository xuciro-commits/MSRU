//
//  MacApplicationWindowControllerTests.swift
//  AppFoundationUITests
//

#if os(macOS)

import AppKit
import Testing

@testable import AppFoundationUI


struct MacApplicationWindowControllerTests {

    @Test
    @MainActor
    func installsContentControllerAndWindowConfiguration() {

        let contentController =
            NSViewController()


        let controller =
            MacApplicationWindowController(
                contentViewController:
                    contentController,
                configuration:
                    .init(
                        title:
                            "Fixture",
                        initialSize:
                            .init(
                                width:
                                    900,
                                height:
                                    640
                            ),
                        minimumSize:
                            .init(
                                width:
                                    700,
                                height:
                                    500
                            )
                    )
            )


        #expect(
            controller
                .window?
                .contentViewController
            ===
            contentController
        )


        #expect(
            controller
                .window?
                .title
            ==
            "Fixture"
        )


        #expect(
            controller
                .window?
                .minSize
                .width
            ==
            700
        )


        #expect(
            controller
                .window?
                .minSize
                .height
            ==
            500
        )
    }


    @Test
    @MainActor
    func retainsAndInstallsToolbarAdapter() {

        let splitController =
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
                                    500
                            )
                    )
            )


        let toolbar =
            MacToolbarAdapter(
                identifier:
                    "AppFoundationUITests.Toolbar"
            ) {

                ResolvedToolbarPresentation()
            }


        let controller =
            MacApplicationWindowController(
                contentViewController:
                    splitController,
                configuration:
                    .init(
                        title:
                            "Fixture"
                    ),
                toolbarAdapter:
                    toolbar
            )


        #expect(
            controller.toolbarAdapter
            ===
            toolbar
        )


        #expect(
            controller
                .window?
                .toolbar
            !=
            nil
        )
    }
}

#endif
