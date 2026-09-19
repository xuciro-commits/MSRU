//
//  WorkspacePresentation.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Workspace Presentation

/// Semantic presentation of an application's primary workspace.
///
/// A workspace describes what is being presented.
///
/// It does not decide how a platform shell arranges navigation,
/// context, toolbar, or accessory regions.
@MainActor
public struct WorkspacePresentation<Context> {

    public let identity:
        WorkspaceIdentity?

    public let toolbar:
        ToolbarPresentation<Context>

    public let context:
        ContextPresentation<Context>?

    public let workspaceAccessory:
        AccessoryPresentation<Context>?


    private let buildContent:
        (Context) -> AnyView


    public init<Content: View>(
        identity:
            WorkspaceIdentity? = nil,
        toolbar:
            ToolbarPresentation<Context> = .init(),
        context:
            ContextPresentation<Context>? = nil,
        workspaceAccessory:
            AccessoryPresentation<Context>? = nil,
        @ViewBuilder content:
            @escaping (Context) -> Content
    ) {

        precondition(
            workspaceAccessory?.scope
            !=
            .application,
            """
            WorkspacePresentation cannot own an
            application-scoped accessory.
            """
        )


        self.identity =
            identity

        self.toolbar =
            toolbar

        self.context =
            context

        self.workspaceAccessory =
            workspaceAccessory

        self.buildContent = {
            context in

            AnyView(
                content(
                    context
                )
            )
        }
    }


    public func content(
        for context:
            Context
    ) -> AnyView {

        buildContent(
            context
        )
    }
}
