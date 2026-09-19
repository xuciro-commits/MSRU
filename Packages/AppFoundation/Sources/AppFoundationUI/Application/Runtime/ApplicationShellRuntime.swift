//
//  ApplicationShellRuntime.swift
//  AppFoundationUI
//

// MARK: - Application Shell Runtime

/// Resolves application semantics into a platform-consumable shell.
///
/// The runtime intentionally separates two context domains:
///
/// - `WorkspaceContext`
/// - `ShellContext`
///
/// A workspace may depend on a scene/domain context while the
/// application shell can depend on a different action-enabled context.
///
/// Neither context escapes the runtime after resolution.
@MainActor
public struct ApplicationShellRuntime<
    Route,
    WorkspaceContext,
    ShellContext
> {

    public let shell:
        ApplicationShellPresentation<ShellContext>


    private let resolveWorkspace:
        (
            Route,
            WorkspaceContext
        ) -> WorkspacePresentation<WorkspaceContext>?


    // MARK: - Resolver Init

    public init(
        shell:
            ApplicationShellPresentation<ShellContext>,
        workspace:
            @escaping (
                Route,
                WorkspaceContext
            ) -> WorkspacePresentation<WorkspaceContext>?
    ) {

        self.shell =
            shell

        self.resolveWorkspace =
            workspace
    }


    // MARK: - Application Definition Init

    public init(
        definition:
            ApplicationDefinition<
                Route,
                WorkspaceContext
            >,
        shell:
            ApplicationShellPresentation<ShellContext>
    ) where Route: Hashable {

        self.init(
            shell:
                shell,
            workspace: {
                route,
                context in

                definition
                    .workspace(
                        for:
                            route,
                        context:
                            context
                    )
            }
        )
    }


    // MARK: - Resolution

    public func resolve(
        route:
            Route,
        workspaceContext:
            WorkspaceContext,
        shellContext:
            ShellContext
    ) -> ResolvedApplicationShell {

        let workspace =
            resolveWorkspace(
                route,
                workspaceContext
            )
            .map {
                ResolvedWorkspacePresentation(
                    presentation:
                        $0,
                    context:
                        workspaceContext
                )
            }


        let applicationContexts =
            shell
                .contexts
                .map {
                    ResolvedContextPresentation(
                        presentation:
                            $0,
                        context:
                            shellContext
                    )
                }


        let applicationAccessories =
            shell
                .accessories
                .map {
                    ResolvedAccessoryPresentation(
                        presentation:
                            $0,
                        context:
                            shellContext
                    )
                }


        let applicationToolbar =
            shell
                .toolbar
                .resolved(
                    for:
                        shellContext
                )


        let toolbar =
            applicationToolbar
                .merging(
                    workspace?
                        .toolbar
                    ??
                    ResolvedToolbarPresentation()
                )


        return
            ResolvedApplicationShell(
                workspace:
                    workspace,
                applicationContexts:
                    applicationContexts,
                applicationAccessories:
                    applicationAccessories,
                toolbar:
                    toolbar
            )
    }
}
