//
//  WorkspacePresentation.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Workspace Presentation

/// Describes the semantic presentation of one active workspace.
///
/// A workspace is the center of the application shell. Navigation, context,
/// accessories, and platform chrome exist in support of it.
///
/// This type deliberately does not know about:
/// - routes
/// - split views
/// - toolbars
/// - windows
/// - AppKit or UIKit
///
/// Those concerns belong to neighboring layers.
@MainActor
public struct WorkspacePresentation<Context> {

    public let identity:
        WorkspaceIdentity?

    public let context:
        ContextPresentation<Context>?

    public let workspaceAccessory:
        AccessoryPresentation<Context>?

    private let buildContent:
        (Context) -> AnyView


    public init<Content: View>(
        identity: WorkspaceIdentity? = nil,
        context: ContextPresentation<Context>? = nil,
        workspaceAccessory: AccessoryPresentation<Context>? = nil,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        precondition(
            workspaceAccessory?.scope != .application,
            """
            WorkspacePresentation may only own workspace-scoped accessories.
            Application-scoped accessories belong to the application shell.
            """
        )

        self.identity =
            identity

        self.context =
            context

        self.workspaceAccessory =
            workspaceAccessory

        self.buildContent = {
            context in

            AnyView(
                content(context)
            )
        }
    }


    public func content(
        for context: Context
    ) -> AnyView {

        buildContent(
            context
        )
    }
}
