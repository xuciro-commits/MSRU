import SwiftUI
import AppFoundation
import AppFoundationUI

// MARK: - Compact Tab

nonisolated enum CompactNavigationTab: String, CaseIterable, Identifiable, Sendable {
    case discovery
    case radio
    case library
    case tools

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .discovery:
            return "Discovery"
        case .radio:
            return "Radio"
        case .library:
            return "Library"
        case .tools:
            return "Tools"
        }
    }

    var systemImage: String {
        switch self {
        case .discovery:
            return "play.circle.fill"
        case .radio:
            return "dot.radiowaves.left.and.right"
        case .library:
            return "square.stack.fill"
        case .tools:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - Compact Application Shell

/// Native iOS / compact form-factor shell adhering to Apple Human Interface Guidelines.
/// Renders a bottom TabView, floating MiniPlayer, contextual sheets, and full-screen Now Playing canvas.
@MainActor
struct CompactApplicationShell: View {

    @Bindable var scene: SceneModel
    let shellSession: MSRUApplicationShellSession

    @State private var selectedTab: CompactNavigationTab = .library

    var body: some View {
        TabView(selection: $selectedTab) {
            discoveryTab
                .tabItem {
                    Label(CompactNavigationTab.discovery.title, systemImage: CompactNavigationTab.discovery.systemImage)
                }
                .tag(CompactNavigationTab.discovery)

            radioTab
                .tabItem {
                    Label(CompactNavigationTab.radio.title, systemImage: CompactNavigationTab.radio.systemImage)
                }
                .tag(CompactNavigationTab.radio)

            libraryTab
                .tabItem {
                    Label(CompactNavigationTab.library.title, systemImage: CompactNavigationTab.library.systemImage)
                }
                .tag(CompactNavigationTab.library)

            toolsTab
                .tabItem {
                    Label(CompactNavigationTab.tools.title, systemImage: CompactNavigationTab.tools.systemImage)
                }
                .tag(CompactNavigationTab.tools)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            floatingMiniPlayer
        }
        .sheet(isPresented: $scene.isQueuePresented) {
            NavigationStack {
                MSRUContextPaneView(scene: scene)
                    .navigationTitle(contextPaneTitle)
                    .compactInlineNavigationBarTitle()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(LocalizedStringKey("Done")) {
                                scene.isQueuePresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .overlay {
            if scene.isNowPlayingPresented {
                NowPlayingCanvasView(
                    playback: scene.application.playback,
                    onClose: {
                        scene.setNowPlaying(presented: false)
                    },
                    lyricsStore: scene.application.services.lyrics,
                    lyricsSearch: scene.application.services.lyricsSearch
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: scene.isNowPlayingPresented)
        .onAppear {
            syncTab(from: scene.navigation.section)
        }
        .onChange(of: scene.navigation.section) { _, newSection in
            syncTab(from: newSection)
        }
        .onChange(of: selectedTab) { _, newTab in
            syncSection(from: newTab)
        }
    }

    // MARK: - Tabs

    private var discoveryTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Discovery Mode", selection: Binding(
                    get: {
                        scene.navigation.section == .browse ? SceneSection.browse : SceneSection.listenNow
                    },
                    set: { newSection in
                        scene.send(.navigate(.section(newSection)))
                    }
                )) {
                    Text(LocalizedStringKey("Home")).tag(SceneSection.listenNow)
                    Text(LocalizedStringKey("Browse")).tag(SceneSection.browse)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                searchableWorkspace
            }
            .navigationTitle(LocalizedStringKey("Discovery"))
            .compactInlineNavigationBarTitle()
        }
    }

    private var radioTab: some View {
        NavigationStack {
            searchableWorkspace
                .navigationTitle(LocalizedStringKey("Radio"))
                .compactInlineNavigationBarTitle()
        }
    }

    private var libraryTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library Dimension", selection: Binding(
                    get: {
                        if scene.navigation.section == .albums { return SceneSection.albums }
                        if scene.navigation.section == .artists { return SceneSection.artists }
                        if scene.navigation.section == .playlists { return SceneSection.playlists }
                        return SceneSection.library
                    },
                    set: { newSection in
                        scene.send(.navigate(.section(newSection)))
                    }
                )) {
                    Text(LocalizedStringKey("Songs")).tag(SceneSection.library)
                    Text(LocalizedStringKey("Albums")).tag(SceneSection.albums)
                    Text(LocalizedStringKey("Artists")).tag(SceneSection.artists)
                    Text(LocalizedStringKey("Playlists")).tag(SceneSection.playlists)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                searchableWorkspace
            }
            .navigationTitle(LocalizedStringKey("Library"))
            .compactInlineNavigationBarTitle()
        }
    }

    private var toolsTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tools Option", selection: Binding(
                    get: {
                        if scene.navigation.section == .importReview { return SceneSection.importReview }
                        if scene.navigation.section == .settings { return SceneSection.settings }
                        return SceneSection.sources
                    },
                    set: { newSection in
                        scene.send(.navigate(.section(newSection)))
                    }
                )) {
                    Text(LocalizedStringKey("Sources")).tag(SceneSection.sources)
                    Text(LocalizedStringKey("Review")).tag(SceneSection.importReview)
                    Text(LocalizedStringKey("Settings")).tag(SceneSection.settings)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                searchableWorkspace
            }
            .navigationTitle(LocalizedStringKey("Tools"))
            .compactInlineNavigationBarTitle()
        }
    }

    // MARK: - Workspace & Searchable

    @ViewBuilder
    private var searchableWorkspace: some View {
        let resolved = shellSession.resolve()
        if let search = resolved.toolbar.items.compactMap({ item -> ResolvedToolbarSearch? in
            if case .search(let search) = item { return search }
            return nil
        }).first, search.isEnabled {
            workspace(from: resolved)
                .searchable(
                    text: Binding(get: { search.text }, set: { search.update($0) }),
                    prompt: Text(search.prompt)
                )
        } else {
            workspace(from: resolved)
        }
    }

    @ViewBuilder
    private func workspace(from resolved: ResolvedApplicationShell) -> some View {
        if let workspace = resolved.workspace {
            workspace.content
        } else {
            ContentUnavailableView(
                LocalizedStringKey("shell.destination_unavailable"),
                systemImage: "questionmark.square.dashed"
            )
        }
    }

    // MARK: - Floating Mini Player

    private var floatingMiniPlayer: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            MiniPlayerBar(
                playback: scene.application.playback,
                onToggleQueue: {
                    scene.activeContextPane = .queue
                    scene.isQueuePresented = true
                },
                onToggleLyrics: {
                    scene.activeContextPane = .lyrics
                    scene.isQueuePresented = true
                },
                onExpandNowPlaying: {
                    scene.setNowPlaying(presented: true)
                }
            )
            .frame(minWidth: 420, maxWidth: 860)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var contextPaneTitle: LocalizedStringKey {
        switch scene.activeContextPane {
        case .inspector:
            return "Details"
        case .queue:
            return "Playing Queue"
        case .lyrics:
            return "Lyrics"
        }
    }

    private func syncTab(from section: SceneSection) {
        switch section {
        case .listenNow, .browse:
            if selectedTab != .discovery { selectedTab = .discovery }
        case .radio:
            if selectedTab != .radio { selectedTab = .radio }
        case .library, .albums, .artists, .playlists:
            if selectedTab != .library { selectedTab = .library }
        case .sources, .importReview, .settings:
            if selectedTab != .tools { selectedTab = .tools }
        }
    }

    private func syncSection(from tab: CompactNavigationTab) {
        switch tab {
        case .discovery:
            if scene.navigation.section != .listenNow && scene.navigation.section != .browse {
                scene.send(.navigate(.section(.listenNow)))
            }
        case .radio:
            if scene.navigation.section != .radio {
                scene.send(.navigate(.section(.radio)))
            }
        case .library:
            if scene.navigation.section != .library && scene.navigation.section != .albums && scene.navigation.section != .artists && scene.navigation.section != .playlists {
                scene.send(.navigate(.section(.library)))
            }
        case .tools:
            if scene.navigation.section != .sources && scene.navigation.section != .importReview && scene.navigation.section != .settings {
                scene.send(.navigate(.section(.sources)))
            }
        }
    }
}

// MARK: - Preview

#Preview("Compact Application Shell · iPhone") {
    let scene = MSRUPreviewData.makeScene()
    let session = MSRUApplicationShellSession(scene: scene)
    CompactApplicationShell(scene: scene, shellSession: session)
}

// MARK: - Platform Navigation Bar Title Helper

private extension View {
    @ViewBuilder
    func compactInlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
