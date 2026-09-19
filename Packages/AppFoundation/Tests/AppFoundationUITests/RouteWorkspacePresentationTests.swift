//
//  RouteWorkspacePresentationTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing

@testable import AppFoundationUI


private enum WorkspaceRoute:
    Hashable,
    Sendable {

    case library
    case item(Int)
}


private struct WorkspaceRouteContext {

    let title:
        String

    let count:
        Int
}


struct RouteWorkspacePresentationTests {

    @Test
    @MainActor
    func exactRouteBuildsWorkspacePresentation() {

        let destination =
            RouteDestination<
                WorkspaceRoute,
                WorkspaceRouteContext
            >(
                id:
                    "library",
                route:
                    .library,
                workspace: {
                    context in

                    WorkspacePresentation(
                        identity:
                            WorkspaceIdentity(
                                title:
                                    context.title,
                                subtitle:
                                    "\(context.count) items"
                            )
                    ) {
                        _ in

                        Text(
                            "Library"
                        )
                    }
                }
            )


        let workspace =
            destination
                .workspace(
                    for:
                        .library,
                    context:
                        WorkspaceRouteContext(
                            title:
                                "Library",
                            count:
                                12
                        )
                )


        #expect(
            workspace.identity?.title
            ==
            "Library"
        )

        #expect(
            workspace.identity?.subtitle
            ==
            "12 items"
        )
    }


    @Test
    @MainActor
    func patternRouteBuildsWorkspacePresentation() {

        let destination =
            RouteDestination<
                WorkspaceRoute,
                WorkspaceRouteContext
            >(
                id:
                    "item",
                matches: {
                    route in

                    if case .item =
                        route {

                        return true
                    }

                    return false
                },
                workspace: {
                    _,
                    context in

                    WorkspacePresentation(
                        identity:
                            WorkspaceIdentity(
                                title:
                                    context.title
                            )
                    ) {
                        _ in

                        Text(
                            "Item"
                        )
                    }
                }
            )


        #expect(
            destination.matches(
                .item(
                    42
                )
            )
        )


        let workspace =
            destination
                .workspace(
                    for:
                        .item(
                            42
                        ),
                    context:
                        WorkspaceRouteContext(
                            title:
                                "Selected Item",
                            count:
                                1
                        )
                )


        #expect(
            workspace.identity?.title
            ==
            "Selected Item"
        )
    }


    @Test
    @MainActor
    func legacyViewDestinationIsWrappedAsWorkspace() {

        let destination =
            RouteDestination<
                WorkspaceRoute,
                WorkspaceRouteContext
            >(
                id:
                    "legacy",
                route:
                    .library
            ) {
                context in

                Text(
                    context.title
                )
            }


        let workspace =
            destination
                .workspace(
                    for:
                        .library,
                    context:
                        WorkspaceRouteContext(
                            title:
                                "Legacy Library",
                            count:
                                10
                        )
                )


        #expect(
            workspace.identity
            ==
            nil
        )

        #expect(
            workspace.context
            ==
            nil
        )

        #expect(
            workspace.workspaceAccessory
            ==
            nil
        )
    }


    @Test
    @MainActor
    func presentationPackResolvesWorkspaceWithoutShellKnowingRoutes() {

        var pack =
            FeaturePresentationPack<
                WorkspaceRoute,
                WorkspaceRouteContext
            >()


        pack.append(
            contentsOf: [

                RouteDestination(
                    id:
                        "library",
                    route:
                        WorkspaceRoute.library,
                    workspace: {
                        context in

                        WorkspacePresentation(
                            identity:
                                WorkspaceIdentity(
                                    title:
                                        context.title
                                )
                        ) {
                            _ in

                            Text(
                                "Library"
                            )
                        }
                    }
                )
            ]
        )


        let workspace =
            pack.workspace(
                for:
                    .library,
                context:
                    WorkspaceRouteContext(
                        title:
                            "Resolved Library",
                        count:
                            4
                    )
            )


        #expect(
            workspace?.identity?.title
            ==
            "Resolved Library"
        )
    }
}
