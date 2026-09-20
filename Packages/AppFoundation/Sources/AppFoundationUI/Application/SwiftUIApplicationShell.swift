#if os(macOS) || os(iOS) || os(visionOS)
import SwiftUI

/// Native split navigation for platforms hosted by SwiftUI WindowGroup.
/// The product owns context visibility; this view only renders resolved semantics.
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
                            Button("完成", systemImage: "checkmark") { isContextPresented = false }
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
            ContentUnavailableView("目标不可用", systemImage: "questionmark.square.dashed")
        }
    }
}

#Preview("SwiftUI Application Shell") {
    @Previewable @State var showsContext = true
    let shell = ApplicationShellResolver<String, String, String>(
        shell: ApplicationShellPresentation(contexts: [
            ContextPresentation(id: "details", role: .inspector) { (_: String) in Text("Selection details").padding() }
        ]),
        workspace: { _, _ in
            WorkspacePresentation(identity: WorkspaceIdentity(title: "Library")) { (_: String) in
                List(["Northern Lights", "Quiet Geometry"], id: \.self) { Text($0) }
            }
        }
    ).resolve(route: "library", workspaceContext: "", shellContext: "")
    SwiftUIApplicationShell(shell: shell, isContextPresented: $showsContext) {
        List { Label("Library", systemImage: "music.note.list") }
    }
    .frame(minWidth: 700, minHeight: 500)
}

#Preview("SwiftUI Application Shell · Compact") {
    @Previewable @State var showsContext = false
    let shell = ApplicationShellResolver<String, String, String>(
        shell: ApplicationShellPresentation(),
        workspace: { _, _ in
            WorkspacePresentation(identity: WorkspaceIdentity(title: "Library")) { (_: String) in
                List(["Northern Lights", "Quiet Geometry"], id: \.self) { Text($0) }
            }
        }
    ).resolve(route: "library", workspaceContext: "", shellContext: "")
    SwiftUIApplicationShell(shell: shell, isContextPresented: $showsContext) {
        List { Label("Library", systemImage: "music.note.list") }
    }
    .frame(width: 360, height: 600)
}
#endif
