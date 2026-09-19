//
//  ApplicationShellRuntimeTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing

@testable import AppFoundationUI


private enum RuntimeTestRoute {

    case home
    case missing
}


private struct RuntimeWorkspaceContext {

    let title:
        String
}


private struct RuntimeShellContext {

    let value:
        String
}


struct ApplicationShellRuntimeTests {

    @Test
    @MainActor
    func resolvesApplicationAndWorkspaceSurfacesTogether() {

        let shell =
            makeApplicationShell()


        let runtime =
            ApplicationShellRuntime<
                RuntimeTestRoute,
                RuntimeWorkspaceContext,
                RuntimeShellContext
            >(
                shell:
                    shell,
                workspace: {
                    route,
                    _ in

                    guard
                        route
                        ==
                        .home
                    else {

                        return
                            nil
                    }


                    return
                        makeWorkspace()
                }
            )


        let resolved =
            runtime.resolve(
                route:
                    .home,
                workspaceContext:
                    .init(
                        title:
                            "Workspace"
                    ),
                shellContext:
                    .init(
                        value:
                            "Application"
                    )
            )


        #expect(
            resolved.workspace
            !=
            nil
        )


        #expect(
            resolved
                .applicationContexts(
                    role:
                        .activity
                )
                .map(
                    \.id
                )
            ==
            [
                "application.activity"
            ]
        )


        #expect(
            resolved
                .applicationAccessories
                .map(
                    \.id
                )
            ==
            [
                "application.accessory"
            ]
        )


        #expect(
            resolved
                .workspace?
                .context?
                .id
            ==
            "workspace.preview"
        )


        #expect(
            resolved
                .workspace?
                .workspaceAccessory?
                .id
            ==
            "workspace.accessory"
        )
    }


    @Test
    @MainActor
    func mergesApplicationAndWorkspaceToolbars() {

        let runtime =
            ApplicationShellRuntime<
                RuntimeTestRoute,
                RuntimeWorkspaceContext,
                RuntimeShellContext
            >(
                shell:
                    makeApplicationShell(),
                workspace: {
                    route,
                    _ in

                    route
                    ==
                    .home
                    ?
                    makeWorkspace()
                    :
                    nil
                }
            )


        let resolved =
            runtime.resolve(
                route:
                    .home,
                workspaceContext:
                    .init(
                        title:
                            "Workspace"
                    ),
                shellContext:
                    .init(
                        value:
                            "Application"
                    )
            )


        #expect(
            resolved
                .toolbar
                .items
                .map(
                    \.id
                )
            ==
            [
                "application.action",
                "workspace.action"
            ]
        )
    }


    @Test
    @MainActor
    func applicationShellSurvivesMissingWorkspace() {

        let runtime =
            ApplicationShellRuntime<
                RuntimeTestRoute,
                RuntimeWorkspaceContext,
                RuntimeShellContext
            >(
                shell:
                    makeApplicationShell(),
                workspace: {
                    _,
                    _ in

                    nil
                }
            )


        let resolved =
            runtime.resolve(
                route:
                    .missing,
                workspaceContext:
                    .init(
                        title:
                            "Unused"
                    ),
                shellContext:
                    .init(
                        value:
                            "Application"
                    )
            )


        #expect(
            resolved.workspace
            ==
            nil
        )


        #expect(
            resolved
                .applicationContexts
                .count
            ==
            1
        )


        #expect(
            resolved
                .applicationAccessories
                .count
            ==
            1
        )


        #expect(
            resolved
                .toolbar
                .items
                .map(
                    \.id
                )
            ==
            [
                "application.action"
            ]
        )
    }


    // MARK: - Fixtures

    @MainActor
    private func makeApplicationShell()
        -> ApplicationShellPresentation<
            RuntimeShellContext
        > {

        ApplicationShellPresentation(
            contexts:
                [
                    ContextPresentation(
                        id:
                            "application.activity",
                        role:
                            .activity
                    ) {
                        context in

                        Text(
                            context.value
                        )
                    }
                ],
            accessories:
                [
                    AccessoryPresentation(
                        id:
                            "application.accessory",
                        scope:
                            .application
                    ) {
                        context in

                        Text(
                            context.value
                        )
                    }
                ],
            toolbar:
                ToolbarPresentation(
                    items:
                        [
                            .action(
                                ToolbarActionPresentation(
                                    id:
                                        "application.action",
                                    title:
                                        "Application Action",
                                    systemImage:
                                        "gear",
                                    perform: {
                                        _ in
                                    }
                                )
                            )
                        ]
                )
        )
    }


    @MainActor
    private func makeWorkspace()
        -> WorkspacePresentation<
            RuntimeWorkspaceContext
        > {

        WorkspacePresentation(
            identity:
                WorkspaceIdentity(
                    title:
                        "Workspace"
                ),
            toolbar:
                ToolbarPresentation(
                    items:
                        [
                            .action(
                                ToolbarActionPresentation(
                                    id:
                                        "workspace.action",
                                    title:
                                        "Workspace Action",
                                    systemImage:
                                        "hammer",
                                    perform: {
                                        _ in
                                    }
                                )
                            )
                        ]
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
                        "workspace.accessory",
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
    }
}
