//
//  WorkspacePresentationTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing

@testable import AppFoundationUI


private struct WorkspaceTestContext {

    let name:
        String

    let selection:
        String
}


struct WorkspacePresentationTests {

    @Test
    func workspaceIdentityIsPureSemanticData() {

        let identity =
            WorkspaceIdentity(
                title:
                    "Reservations",
                subtitle:
                    "September 19",
                systemImage:
                    "calendar"
            )


        #expect(
            identity.title
            ==
            "Reservations"
        )

        #expect(
            identity.subtitle
            ==
            "September 19"
        )

        #expect(
            identity.systemImage
            ==
            "calendar"
        )
    }


    @Test
    @MainActor
    func workspaceBuildsContentFromContext() {

        var observedName:
            String?


        let presentation =
            WorkspacePresentation<
                WorkspaceTestContext
            > {
                context in

                observedName =
                    context.name

                return
                    Text(
                        context.name
                    )
            }


        _ =
            presentation
                .content(
                    for:
                        WorkspaceTestContext(
                            name:
                                "Inventory",
                            selection:
                                "Item A"
                        )
                )


        #expect(
            observedName
            ==
            "Inventory"
        )
    }


    @Test
    @MainActor
    func contextPresentationPreservesSemanticRole() {

        let presentation =
            ContextPresentation<
                WorkspaceTestContext
            >(
                id:
                    "selection",
                role:
                    .inspector
            ) {
                context in

                Text(
                    context.selection
                )
            }


        #expect(
            presentation.id
            ==
            "selection"
        )

        #expect(
            presentation.role
            ==
            .inspector
        )
    }


    @Test
    @MainActor
    func accessoryScopeIsExplicit() {

        let accessory =
            AccessoryPresentation<
                WorkspaceTestContext
            >(
                id:
                    "timeline-controls",
                scope:
                    .workspace
            ) {
                _ in

                Text(
                    "Controls"
                )
            }


        #expect(
            accessory.scope
            ==
            .workspace
        )
    }


    @Test
    @MainActor
    func workspaceCarriesContextAndWorkspaceAccessory() {

        let context =
            ContextPresentation<
                WorkspaceTestContext
            >(
                id:
                    "preview",
                role:
                    .preview
            ) {
                _ in

                Text(
                    "Preview"
                )
            }


        let accessory =
            AccessoryPresentation<
                WorkspaceTestContext
            >(
                id:
                    "status",
                scope:
                    .workspace
            ) {
                _ in

                Text(
                    "Status"
                )
            }


        let workspace =
            WorkspacePresentation<
                WorkspaceTestContext
            >(
                identity:
                    WorkspaceIdentity(
                        title:
                            "Rooms"
                    ),
                context:
                    context,
                workspaceAccessory:
                    accessory
            ) {
                _ in

                Text(
                    "Rooms"
                )
            }


        #expect(
            workspace.identity?.title
            ==
            "Rooms"
        )

        #expect(
            workspace.context?.id
            ==
            "preview"
        )

        #expect(
            workspace.workspaceAccessory?.id
            ==
            "status"
        )
    }
}
