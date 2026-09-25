//
//  SourcesView.swift
//  MSRU
//
//  The one place for where music comes from: files, watched folders, servers
//  and Apple Music are added, checked and removed here.
//

import SwiftUI
import UniformTypeIdentifiers
import AppFoundation
import AppFoundationUI
import MusicLibrary

struct SourcesView: View {
    @Bindable var scene: SceneModel

    @State private var picker: PickerKind = .files
    @State private var isPickerPresented = false
    @State private var sheet: Sheet?
    @State private var sourcePendingRemoval: Source?
    @State private var importErrorMessage: String?

    private var application: ApplicationModel { scene.application }
    private var coordinator: SourceRuntimeCoordinator { application.subsonicServers.coordinator }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(spacing: 16) {
                    ForEach(sortedSources) { source in
                        SourceCard(
                            source: source,
                            coordinator: coordinator,
                            onShowInLibrary: {
                                scene.navigateToSource(sourceID: source.id.rawValue, target: .library)
                            },
                            onImportAgain: { sheet = .appleMusic },
                            onRemove: { sourcePendingRemoval = source }
                        )
                    }
                }

                Divider()

                WatchedFoldersSection(
                    watchedFolders: application.watchedFolders,
                    onAddFolder: { present(.folder) }
                )
            }
            .padding(28)
        }
        .hideScrollIndicatorsCompletely()
        .task {
            await coordinator.bootstrapAll()
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: picker == .folder ? [.folder] : LocalAudioFormatSupport.importContentTypes,
            allowsMultipleSelection: picker == .files
        ) { result in
            handlePicked(result)
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .server:
                AddSubsonicServerSheet(store: application.subsonicServers) {
                    self.sheet = nil
                    Task { await coordinator.bootstrapAll() }
                }
            case .appleMusic:
                appleMusicSheet
            }
        }
        .confirmationDialog(
            removalTitle,
            isPresented: Binding(
                get: { sourcePendingRemoval != nil },
                set: { if !$0 { sourcePendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: sourcePendingRemoval
        ) { source in
            Button("Remove", role: .destructive) {
                Task { await remove(source) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its songs are removed from your library. Files on the server and in Apple Music are not touched.")
        }
        .alert(
            "Couldn't Import Files",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sources")
                    .font(.largeTitle.bold())
                Text("Everything in your library comes from here: files, folders, servers and Apple Music.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("Import Files…", systemImage: "doc.badge.plus") { present(.files) }
                Button("Watch a Folder…", systemImage: "folder.badge.plus") { present(.folder) }
                Divider()
                Button("Connect a Server…", systemImage: "server.rack") { sheet = .server }
                Button("Import from Apple Music…", systemImage: "apple.logo") { sheet = .appleMusic }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .fixedSize()
        }
    }

    private var appleMusicSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { sheet = nil }
                    .keyboardShortcut(.cancelAction)
            }
            .padding([.top, .horizontal], 16)

            AppleMusicImportView(
                store: application.musicLibrary,
                localStore: application.localLibrary,
                playlistStore: application.playlistStore,
                onImportCompleted: {
                    sheet = nil
                    Task { await coordinator.bootstrapAll() }
                    scene.send(.navigate(.section(.library)))
                }
            )
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    // MARK: - Sources

    /// Local first, then servers, Apple Music and web catalogues, each by name.
    private var sortedSources: [Source] {
        coordinator.activeSources.sorted {
            let lhs = SourceKind($0), rhs = SourceKind($1)
            if lhs != rhs { return lhs < rhs }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var removalTitle: Text {
        Text("Remove “\(sourcePendingRemoval?.displayName ?? "")”?")
    }

    private func remove(_ source: Source) async {
        await coordinator.removeSource(id: source.id)
        if source.id == WebLibraryIndex.sourceID {
            await application.webLibrary.load()
        }
    }

    // MARK: - Pickers

    private func present(_ kind: PickerKind) {
        picker = kind
        isPickerPresented = true
    }

    private func handlePicked(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            switch picker {
            case .files:
                Task {
                    await application.localLibrary.importFiles(urls)
                    scene.send(.navigate(.section(.library)))
                }
            case .folder:
                guard let url = urls.first else { return }
                Task { await application.watchedFolders.addFolder(url: url) }
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                importErrorMessage = error.localizedDescription
            }
        }
    }
}

private extension SourcesView {
    enum PickerKind {
        case files
        case folder
    }

    enum Sheet: String, Identifiable {
        case server
        case appleMusic
        var id: String { rawValue }
    }
}

// MARK: - Source Kind

private enum SourceKind: Int, Comparable {
    case local
    case server
    case appleMusic
    case web

    init(_ source: Source) {
        switch source.sourceType {
        case .localFolder, .networkFolder: self = .local
        case .subsonic: self = .server
        case .appleMusic: self = .appleMusic
        case .futureProvider: self = source.id.isLocal ? .local : .web
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var systemImage: String {
        switch self {
        case .local: "internaldrive.fill"
        case .server: "server.rack"
        case .appleMusic: "apple.logo"
        case .web: "globe"
        }
    }
}

// MARK: - Source Card

private struct SourceCard: View {
    let source: Source
    let coordinator: SourceRuntimeCoordinator
    let onShowInLibrary: () -> Void
    let onImportAgain: () -> Void
    let onRemove: () -> Void

    @State private var stats: (tracks: Int, albums: Int)?

    private var kind: SourceKind { SourceKind(source) }
    private var isRefreshing: Bool { coordinator.isReconciling[source.id] == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        title
                            .font(.headline)
                        if kind == .server {
                            statusPill
                        }
                    }
                    subtitle
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if kind == .server, case .offline(let message) = coordinator.status[source.id] {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if kind != .local {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this source")
                }
            }

            Divider()

            HStack(spacing: 16) {
                statItem("Songs", value: stats?.tracks)
                statItem("Albums", value: stats?.albums)

                Spacer()

                if kind == .server, let lastConnected = source.lastReconciledAt {
                    Text("Last connected \(lastConnected.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 10) {
                Button(action: onShowInLibrary) {
                    Label("Show in Library", systemImage: "music.note.house")
                }

                Spacer()

                switch kind {
                case .server:
                    Button {
                        Task {
                            await coordinator.reconcileSource(source)
                            await loadStats()
                        }
                    } label: {
                        Label(
                            isRefreshing ? LocalizedStringKey("Refreshing…") : LocalizedStringKey("Refresh"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(isRefreshing)
                case .appleMusic:
                    Button(action: onImportAgain) {
                        Label("Import Again…", systemImage: "arrow.down.circle")
                    }
                case .local, .web:
                    EmptyView()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: source.lastReconciledAt) {
            await loadStats()
        }
    }

    /// The default local source's stored name is written by the library in
    /// English; show it localized. Other sources show the name the user chose.
    private var title: Text {
        source.id == .defaultLocal ? Text("Local Files") : Text(verbatim: source.displayName)
    }

    @ViewBuilder
    private var subtitle: some View {
        switch kind {
        case .local:
            Text("Files imported on this device")
        case .server:
            Text(verbatim: source.username.map { "\(source.uri) · \($0)" } ?? source.uri)
        case .appleMusic:
            Text("Imported from your Apple Music library")
        case .web:
            Text("Saved from Openverse")
        }
    }

    private var statusPill: some View {
        let (label, color): (LocalizedStringKey, Color) = {
            if isRefreshing { return ("Refreshing…", .blue) }
            switch coordinator.status[source.id] ?? .unknown {
            case .online: return ("Online", .green)
            case .offline: return ("Offline", .red)
            case .unknown: return ("Not Checked", .secondary)
            }
        }()
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
    }

    private func statItem(_ title: LocalizedStringKey, value: Int?) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            if let value {
                Text(value, format: .number)
                    .monospacedDigit()
            } else {
                Text(verbatim: "–")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
    }

    private func loadStats() async {
        let loaded = await coordinator.fetchSourceStats(sourceID: source.id)
        stats = (tracks: loaded.tracks, albums: loaded.albums)
    }
}

// MARK: - Feature

enum SourcesFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "sources",
                    group: "Source & Import",
                    title: "Sources",
                    systemImage: "server.rack",
                    route: .section(.sources),
                    order: 200
                )
            ],
            routes: [
                RouteContribution(
                    id: "sources",
                    route: .section(.sources)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "sources",
                route: .section(.sources)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Sources"),
                        systemImage: "server.rack"
                    )
                ) { _ in
                    SourcesView(scene: scene)
                }
            }
        ]
    }
}

// MARK: - Preview

#Preview("Sources View") {
    SourcesView(scene: MSRUPreviewData.makeScene(section: .sources))
        .frame(width: 800, height: 600)
}

#Preview("Source Card") {
    SourceCard(
        source: Source(
            id: .defaultLocal,
            sourceType: .localFolder,
            uri: "/Preview/Music",
            displayName: "Local Files",
            capabilities: .localFolderDefault,
            isEnabled: true
        ),
        coordinator: .preview(),
        onShowInLibrary: {},
        onImportAgain: {},
        onRemove: {}
    )
    .frame(width: 700)
    .padding()
}
