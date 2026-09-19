//
//  ResolvedApplicationShell.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Resolved Context

/// A context presentation after its application-specific
/// Context value has been consumed.
@MainActor
public struct ResolvedContextPresentation {

    public let id:
        String

    public let role:
        ContextRole

    public let content:
        AnyView


    init<Context>(
        presentation:
            ContextPresentation<Context>,
        context:
            Context
    ) {

        self.id =
            presentation.id

        self.role =
            presentation.role

        self.content =
            presentation
                .content(
                    for:
                        context
                )
    }
}


// MARK: - Resolved Accessory

/// An accessory presentation after its application-specific
/// Context value has been consumed.
@MainActor
public struct ResolvedAccessoryPresentation {

    public let id:
        String

    public let scope:
        AccessoryScope

    public let content:
        AnyView


    init<Context>(
        presentation:
            AccessoryPresentation<Context>,
        context:
            Context
    ) {

        self.id =
            presentation.id

        self.scope =
            presentation.scope

        self.content =
            presentation
                .content(
                    for:
                        context
                )
    }
}


// MARK: - Resolved Workspace

/// Fully resolved semantic workspace.
///
/// The original Context type has been consumed here, so a platform
/// renderer no longer needs to know the application's scene model.
@MainActor
public struct ResolvedWorkspacePresentation {

    public let identity:
        WorkspaceIdentity?

    public let toolbar:
        ResolvedToolbarPresentation

    public let context:
        ResolvedContextPresentation?

    public let workspaceAccessory:
        ResolvedAccessoryPresentation?

    public let content:
        AnyView


    init<Context>(
        presentation:
            WorkspacePresentation<Context>,
        context:
            Context
    ) {

        self.identity =
            presentation.identity


        self.toolbar =
            presentation
                .toolbar
                .resolved(
                    for:
                        context
                )


        self.context =
            presentation
                .context
                .map {
                    ResolvedContextPresentation(
                        presentation:
                            $0,
                        context:
                            context
                    )
                }


        self.workspaceAccessory =
            presentation
                .workspaceAccessory
                .map {
                    ResolvedAccessoryPresentation(
                        presentation:
                            $0,
                        context:
                            context
                    )
                }


        self.content =
            presentation
                .content(
                    for:
                        context
                )
    }
}


// MARK: - Resolved Application Shell

/// A complete semantic shell snapshot ready for a platform renderer.
///
/// All application-specific generic Context types have already been
/// consumed by `ApplicationShellRuntime`.
@MainActor
public struct ResolvedApplicationShell {

    public let workspace:
        ResolvedWorkspacePresentation?

    public let applicationContexts:
        [ResolvedContextPresentation]

    public let applicationAccessories:
        [ResolvedAccessoryPresentation]

    public let toolbar:
        ResolvedToolbarPresentation


    init(
        workspace:
            ResolvedWorkspacePresentation?,
        applicationContexts:
            [ResolvedContextPresentation],
        applicationAccessories:
            [ResolvedAccessoryPresentation],
        toolbar:
            ResolvedToolbarPresentation
    ) {

        self.workspace =
            workspace

        self.applicationContexts =
            applicationContexts

        self.applicationAccessories =
            applicationAccessories

        self.toolbar =
            toolbar
    }


    // MARK: - Context Resolution

    public func applicationContext(
        id:
            String
    ) -> ResolvedContextPresentation? {

        applicationContexts
            .first {
                $0.id
                ==
                id
            }
    }


    public func applicationContexts(
        role:
            ContextRole
    ) -> [ResolvedContextPresentation] {

        applicationContexts
            .filter {
                $0.role
                ==
                role
            }
    }


    // MARK: - Accessory Resolution

    public func applicationAccessory(
        id:
            String
    ) -> ResolvedAccessoryPresentation? {

        applicationAccessories
            .first {
                $0.id
                ==
                id
            }
    }
}
