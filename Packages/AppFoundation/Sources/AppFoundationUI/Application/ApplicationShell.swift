//
//  ApplicationShell.swift
//  AppFoundationUI
//

import SwiftUI

// MARK: - Application Shell Presentation

/// Describes application-level supporting presentation surfaces.
@MainActor
public struct ApplicationShellPresentation<Context> {
    public let contexts: [ContextPresentation<Context>]
    public let accessories: [AccessoryPresentation<Context>]
    public let toolbar: ToolbarPresentation<Context>

    public init(
        contexts: [ContextPresentation<Context>] = [],
        accessories: [AccessoryPresentation<Context>] = [],
        toolbar: ToolbarPresentation<Context> = .init()
    ) {
        precondition(
            accessories.allSatisfy { $0.scope == .application },
            "ApplicationShellPresentation may only contain application-scoped accessories."
        )
        self.contexts = contexts
        self.accessories = accessories
        self.toolbar = toolbar
    }

    public func context(id: String) -> ContextPresentation<Context>? {
        contexts.first { $0.id == id }
    }

    public func accessory(id: String) -> AccessoryPresentation<Context>? {
        accessories.first { $0.id == id }
    }

    public func contexts(role: ContextRole) -> [ContextPresentation<Context>] {
        contexts.filter { $0.role == role }
    }
}

// MARK: - Resolved Context Presentation

@MainActor
public struct ResolvedContextPresentation {
    public let id: String
    public let role: ContextRole
    public let content: AnyView

    init<Context>(
        presentation: ContextPresentation<Context>,
        context: Context
    ) {
        self.id = presentation.id
        self.role = presentation.role
        self.content = presentation.content(for: context)
    }
}

// MARK: - Resolved Accessory Presentation

@MainActor
public struct ResolvedAccessoryPresentation {
    public let id: String
    public let scope: AccessoryScope
    public let content: AnyView

    init<Context>(
        presentation: AccessoryPresentation<Context>,
        context: Context
    ) {
        self.id = presentation.id
        self.scope = presentation.scope
        self.content = presentation.content(for: context)
    }
}

// MARK: - Resolved Workspace Presentation

@MainActor
public struct ResolvedWorkspacePresentation {
    public let identity: WorkspaceIdentity?
    public let toolbar: ResolvedToolbarPresentation
    public let context: ResolvedContextPresentation?
    public let workspaceAccessory: ResolvedAccessoryPresentation?
    public let content: AnyView

    init<Context>(
        presentation: WorkspacePresentation<Context>,
        context: Context
    ) {
        self.identity = presentation.identity
        self.toolbar = presentation.toolbar.resolved(for: context)
        self.context = presentation.context.map {
            ResolvedContextPresentation(presentation: $0, context: context)
        }
        self.workspaceAccessory = presentation.workspaceAccessory.map {
            ResolvedAccessoryPresentation(presentation: $0, context: context)
        }
        self.content = presentation.content(for: context)
    }
}

// MARK: - Resolved Application Shell

@MainActor
public struct ResolvedApplicationShell {
    public let workspace: ResolvedWorkspacePresentation?
    public let applicationContexts: [ResolvedContextPresentation]
    public let applicationAccessories: [ResolvedAccessoryPresentation]
    public let toolbar: ResolvedToolbarPresentation

    init(
        workspace: ResolvedWorkspacePresentation?,
        applicationContexts: [ResolvedContextPresentation],
        applicationAccessories: [ResolvedAccessoryPresentation],
        toolbar: ResolvedToolbarPresentation
    ) {
        self.workspace = workspace
        self.applicationContexts = applicationContexts
        self.applicationAccessories = applicationAccessories
        self.toolbar = toolbar
    }

    public func applicationContext(id: String) -> ResolvedContextPresentation? {
        applicationContexts.first { $0.id == id }
    }

    public func applicationContexts(role: ContextRole) -> [ResolvedContextPresentation] {
        applicationContexts.filter { $0.role == role }
    }

    public func applicationAccessory(id: String) -> ResolvedAccessoryPresentation? {
        applicationAccessories.first { $0.id == id }
    }
}

// MARK: - Application Shell Resolver

@MainActor
public struct ApplicationShellResolver<Route, WorkspaceContext, ShellContext> {
    public let shell: ApplicationShellPresentation<ShellContext>
    private let resolveWorkspace: (Route, WorkspaceContext) -> WorkspacePresentation<WorkspaceContext>?

    public init(
        shell: ApplicationShellPresentation<ShellContext>,
        workspace: @escaping (Route, WorkspaceContext) -> WorkspacePresentation<WorkspaceContext>?
    ) {
        self.shell = shell
        self.resolveWorkspace = workspace
    }

    public init(
        definition: ApplicationDefinition<Route, WorkspaceContext>,
        shell: ApplicationShellPresentation<ShellContext>
    ) where Route: Hashable {
        self.init(
            shell: shell,
            workspace: { route, context in
                definition.workspace(for: route, context: context)
            }
        )
    }

    public func resolve(
        route: Route,
        workspaceContext: WorkspaceContext,
        shellContext: ShellContext
    ) -> ResolvedApplicationShell {
        let workspace = resolveWorkspace(route, workspaceContext).map {
            ResolvedWorkspacePresentation(presentation: $0, context: workspaceContext)
        }

        let applicationContexts = shell.contexts.map {
            ResolvedContextPresentation(presentation: $0, context: shellContext)
        }

        let applicationAccessories = shell.accessories.map {
            ResolvedAccessoryPresentation(presentation: $0, context: shellContext)
        }

        let applicationToolbar = shell.toolbar.resolved(for: shellContext)
        let toolbar = applicationToolbar.merging(
            workspace?.toolbar ?? ResolvedToolbarPresentation()
        )

        return ResolvedApplicationShell(
            workspace: workspace,
            applicationContexts: applicationContexts,
            applicationAccessories: applicationAccessories,
            toolbar: toolbar
        )
    }
}

// MARK: - SwiftUI Application Shell

#if os(macOS) || os(iOS) || os(visionOS)
@MainActor
public struct SwiftUIApplicationShell<Navigation: View>: View {
    private let shell: ResolvedApplicationShell
    @Binding private var isContextPresented: Bool
    private let navigation: Navigation
    private let externalColumnVisibility: Binding<NavigationSplitViewVisibility>?
    @State private var internalColumnVisibility: NavigationSplitViewVisibility = .automatic

    public init(
        shell: ResolvedApplicationShell,
        isContextPresented: Binding<Bool>,
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
        @ViewBuilder navigation: () -> Navigation
    ) {
        precondition(shell.toolbar.items.filter {
            if case .search = $0 { return true }
            return false
        }.count <= 1, "SwiftUI shell supports one native search field per workspace")
        self.shell = shell
        self._isContextPresented = isContextPresented
        self.externalColumnVisibility = columnVisibility
        self.navigation = navigation()
    }

    private var resolvedColumnVisibility: Binding<NavigationSplitViewVisibility> {
        externalColumnVisibility ?? $internalColumnVisibility
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: resolvedColumnVisibility) {
            navigation
        } detail: {
            searchableWorkspace
                .navigationTitle(shell.workspace?.identity?.title ?? "")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        ForEach(shell.toolbar.items, id: \.id) { item in
                            if case .action(let action) = item {
                                Button(action.title, systemImage: action.systemImage) {
                                    action.perform()
                                }
                                .disabled(!action.isEnabled)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        if let accessory = shell.workspace?.workspaceAccessory {
                            accessory.content
                        }
                        ForEach(shell.applicationAccessories, id: \.id) { accessory in
                            accessory.content
                        }
                    }
                }
                #if os(visionOS)
                .sheet(isPresented: $isContextPresented) {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button(
                                String(localized: "shell.done", bundle: .module),
                                systemImage: "checkmark"
                            ) { isContextPresented = false }
                        }
                        .padding()
                        contextContent
                    }
                    .frame(minWidth: 320, idealWidth: 400, minHeight: 400)
                }
                #else
                .inspector(isPresented: $isContextPresented) {
                    contextContent.inspectorColumnWidth(min: 260, ideal: 320, max: 420)
                }
                #endif
        }
    }

    private var contextContent: some View {
        VStack(spacing: 0) {
            if let context = shell.workspace?.context { context.content }
            ForEach(shell.applicationContexts, id: \.id) { context in context.content }
        }
    }

    @ViewBuilder
    private var searchableWorkspace: some View {
        if let search = shell.toolbar.items.compactMap({ item -> ResolvedToolbarSearch? in
            if case .search(let search) = item { return search }
            return nil
        }).first, search.isEnabled {
            workspace.searchable(
                text: Binding(get: { search.text }, set: { search.update($0) }),
                prompt: Text(search.prompt)
            )
        } else {
            workspace
        }
    }

    @ViewBuilder
    private var workspace: some View {
        if let workspace = shell.workspace {
            workspace.content
        } else {
            ContentUnavailableView(
                String(localized: "shell.destination_unavailable", bundle: .module),
                systemImage: "questionmark.square.dashed"
            )
        }
    }
}
#endif
