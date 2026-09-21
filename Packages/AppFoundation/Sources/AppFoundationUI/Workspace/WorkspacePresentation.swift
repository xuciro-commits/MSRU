//
//  WorkspacePresentation.swift
//  AppFoundationUI
//

import SwiftUI

// MARK: - Accessory Scope & Presentation

/// Defines the lifetime of an accessory presentation.
public enum AccessoryScope: String, Hashable, Sendable {
    /// Persists while the application or scene changes workspaces.
    case application
    /// Belongs to one workspace and disappears when that workspace is replaced.
    case workspace
}

/// A persistent supporting surface that is not the primary command surface.
@MainActor
public struct AccessoryPresentation<Context> {
    public let id: String
    public let scope: AccessoryScope
    private let buildContent: (Context) -> AnyView

    public init<Content: View>(
        id: String,
        scope: AccessoryScope,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        self.id = id
        self.scope = scope
        self.buildContent = { context in
            AnyView(content(context))
        }
    }

    public func content(for context: Context) -> AnyView {
        buildContent(context)
    }
}

// MARK: - Context Role & Presentation

/// Describes what a contextual presentation means.
public enum ContextRole: String, Hashable, Sendable {
    case inspector
    case preview
    case activity
    case utility
}

/// A semantic contextual surface associated with a workspace.
@MainActor
public struct ContextPresentation<Context> {
    public let id: String
    public let role: ContextRole
    private let buildContent: (Context) -> AnyView

    public init<Content: View>(
        id: String,
        role: ContextRole,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        self.id = id
        self.role = role
        self.buildContent = { context in
            AnyView(content(context))
        }
    }

    public func content(for context: Context) -> AnyView {
        buildContent(context)
    }
}

// MARK: - Workspace Identity

/// Describes the semantic identity of the active workspace.
public struct WorkspaceIdentity: Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let systemImage: String?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

// MARK: - Workspace Presentation

/// Semantic presentation of an application's primary workspace.
@MainActor
public struct WorkspacePresentation<Context> {
    public let identity: WorkspaceIdentity?
    public let toolbar: ToolbarPresentation<Context>
    public let context: ContextPresentation<Context>?
    public let workspaceAccessory: AccessoryPresentation<Context>?
    private let buildContent: (Context) -> AnyView

    public init<Content: View>(
        identity: WorkspaceIdentity? = nil,
        toolbar: ToolbarPresentation<Context> = .init(),
        context: ContextPresentation<Context>? = nil,
        workspaceAccessory: AccessoryPresentation<Context>? = nil,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        precondition(
            workspaceAccessory?.scope != .application,
            "WorkspacePresentation cannot own an application-scoped accessory."
        )
        self.identity = identity
        self.toolbar = toolbar
        self.context = context
        self.workspaceAccessory = workspaceAccessory
        self.buildContent = { context in
            AnyView(content(context))
        }
    }

    public func content(for context: Context) -> AnyView {
        buildContent(context)
    }
}

// MARK: - Workspace Safe Area Insets Environment

private struct WorkspaceSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

public extension EnvironmentValues {
    var workspaceSafeAreaInsets: EdgeInsets {
        get { self[WorkspaceSafeAreaInsetsKey.self] }
        set { self[WorkspaceSafeAreaInsetsKey.self] = newValue }
    }
}

// MARK: - Workspace Content View

@MainActor
public struct WorkspaceContentView<Context>: View {
    private let presentation: WorkspacePresentation<Context>
    private let context: Context

    public init(
        presentation: WorkspacePresentation<Context>,
        context: Context
    ) {
        self.presentation = presentation
        self.context = context
    }

    public var body: some View {
        presentation.content(for: context)
    }
}
