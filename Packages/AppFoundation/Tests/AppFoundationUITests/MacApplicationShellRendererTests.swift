//
//  MacApplicationShellRendererTests.swift
//  AppFoundationUITests
//

#if os(macOS)

import AppKit
import SwiftUI
import Testing

@testable import AppFoundationUI


private struct RendererTestContext {

    let title:
        String
}


struct MacApplicationShellRendererTests {

    @Test
    @MainActor
    func rendersResolvedWorkspaceContextAndAccessories() {

        let shell =
            makeShell(
                workspaceTitle:
                    "Orders",
                contextID:
                    "activity.orders",
                applicationAccessoryID:
                    "application.status",
                workspaceAccessoryID:
                    "workspace.controls"
            )


        let renderer =
            makeRenderer(
                shell:
                    shell
            )


        #expect(
            renderer
                .currentWorkspaceIdentity?
                .title
            ==
            "Orders"
        )


        #expect(
            renderer
                .currentContextID
            ==
            "activity.orders"
        )


        #expect(
            renderer
                .currentApplicationAccessoryID
            ==
            "application.status"
        )


        #expect(
            renderer
                .currentWorkspaceAccessoryID
            ==
            "workspace.controls"
        )


        /*
         NSSplitViewController installs its native split items
         during view loading.

         Production Window hosting performs this automatically.
         The unit test must exercise the same lifecycle before
         inspecting AppKit state.
         */

        _ =
            renderer
                .splitController
                .view


        #expect(
            renderer
                .splitController
                .splitViewItems
                .count
            ==
            3
        )
    }


    @Test
    @MainActor
    func applyChangesWorkspaceWithoutRebuildingSplitController() {

        let first =
            makeShell(
                workspaceTitle:
                    "Orders",
                contextID:
                    "activity.orders",
                applicationAccessoryID:
                    "application.status",
                workspaceAccessoryID:
                    "workspace.orders"
            )


        let renderer =
            makeRenderer(
                shell:
                    first
            )


        let splitController =
            renderer
                .splitController


        let second =
            makeShell(
                workspaceTitle:
                    "Inventory",
                contextID:
                    "activity.inventory",
                applicationAccessoryID:
                    "application.status",
                workspaceAccessoryID:
                    "workspace.inventory"
            )


        renderer.apply(
            second
        )


        #expect(
            renderer
                .splitController
            ===
            splitController
        )


        #expect(
            renderer
                .currentWorkspaceIdentity?
                .title
            ==
            "Inventory"
        )


        #expect(
            renderer
                .currentContextID
            ==
            "activity.inventory"
        )


        #expect(
            renderer
                .currentWorkspaceAccessoryID
            ==
            "workspace.inventory"
        )
    }


    @Test
    @MainActor
    func productChoosesWhichSemanticContextOwnsNativeSlot() {

        let shell =
            makeShell(
                workspaceTitle:
                    "Orders",
                contextID:
                    "activity.orders",
                applicationAccessoryID:
                    "application.status",
                workspaceAccessoryID:
                    "workspace.controls"
            )


        let navigation =
            NSViewController()


        let renderer =
            MacApplicationShellRenderer(
                navigationViewController:
                    navigation,
                shell:
                    shell,
                configuration:
                    .init(
                        split:
                            splitConfiguration(),
                        context:
                            .init(
                                region:
                                    contextRegion(),
                                resolve: {
                                    shell in

                                    shell
                                        .workspace?
                                        .context
                                }
                            )
                    )
            )


        #expect(
            renderer
                .currentContextID
            ==
            "workspace.preview"
        )
    }


    // MARK: - Renderer Fixture

    @MainActor
    private func makeRenderer(
        shell:
            ResolvedApplicationShell
    ) -> MacApplicationShellRenderer {

        MacApplicationShellRenderer(
            navigationViewController:
                NSViewController(),
            shell:
                shell,
            configuration:
                .init(
                    split:
                        splitConfiguration(),
                    context:
                        .init(
                            region:
                                contextRegion(),
                            resolve: {
                                shell in

                                shell
                                    .applicationContexts
                                    .first
                            }
                        ),
                    applicationAccessory:
                        .init(
                            resolve: {
                                shell in

                                shell
                                    .applicationAccessories
                                    .first
                            }
                        )
                )
        )
    }


    @MainActor
    private func splitConfiguration()
        -> MacApplicationSplitConfiguration {

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
    }


    @MainActor
    private func contextRegion()
        -> MacSplitRegionConfiguration {

        .init(
            canCollapse:
                true,
            minimumThickness:
                260,
            maximumThickness:
                420
        )
    }


    // MARK: - Semantic Fixture

    @MainActor
    private func makeShell(
        workspaceTitle:
            String,
        contextID:
            String,
        applicationAccessoryID:
            String,
        workspaceAccessoryID:
            String
    ) -> ResolvedApplicationShell {

        let context =
            RendererTestContext(
                title:
                    workspaceTitle
            )


        let workspace =
            WorkspacePresentation<
                RendererTestContext
            >(
                identity:
                    .init(
                        title:
                            workspaceTitle
                    ),
                context:
                    ContextPresentation(
                        id:
                            "workspace.preview",
                        role:
                            .preview
                    ) {
                        context in

                        Text(
                            context.title
                        )
                    },
                workspaceAccessory:
                    AccessoryPresentation(
                        id:
                            workspaceAccessoryID,
                        scope:
                            .workspace
                    ) {
                        context in

                        Text(
                            context.title
                        )
                    }
            ) {
                context in

                Text(
                    context.title
                )
            }


        let resolvedWorkspace =
            ResolvedWorkspacePresentation(
                presentation:
                    workspace,
                context:
                    context
            )


        let applicationContext =
            ResolvedContextPresentation(
                presentation:
                    ContextPresentation(
                        id:
                            contextID,
                        role:
                            .activity
                    ) {
                        context in

                        Text(
                            context.title
                        )
                    },
                context:
                    context
            )


        let applicationAccessory =
            ResolvedAccessoryPresentation(
                presentation:
                    AccessoryPresentation(
                        id:
                            applicationAccessoryID,
                        scope:
                            .application
                    ) {
                        context in

                        Text(
                            context.title
                        )
                    },
                context:
                    context
            )


        return
            ResolvedApplicationShell(
                workspace:
                    resolvedWorkspace,
                applicationContexts:
                    [
                        applicationContext
                    ],
                applicationAccessories:
                    [
                        applicationAccessory
                    ],
                toolbar:
                    ResolvedToolbarPresentation()
            )
    }
}

#endif
