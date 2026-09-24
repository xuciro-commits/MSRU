//
//  PlaylistsView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import CryptoKit
import SubsonicKit
import MusicLibrary
import MusicPlayback

enum PlaylistSortField: String, CaseIterable, Identifiable {
    case title = "Title"
    case recentlyModified = "Recently Modified"
    case songCount = "Song Count"

    var id: String { rawValue }
}

@MainActor
struct PlaylistsView: View {
    @Bindable var playlistStore: PlaylistStore
    let localStore: LocalLibraryStore
    var subsonicServers: SubsonicServerStore? = nil
    let playback: PlaybackController
    @Binding var selectedSourceID: String?
    var onSelectTrack: ((LocalTrack) -> Void)?

    @State private var availableSources: [SourceFilterItem] = []
    @Binding private var searchQuery: String
    @State private var sortField: PlaylistSortField = .title
    @State private var selectedPlaylistID: UUID?
    @State private var fallbackSelectedPlaylist: Playlist?
    @State private var selectedPlaylistTracks: [LocalTrack] = []
    @State private var playlistArtworkRefs: [UUID: String] = [:]
    @State private var isNewPlaylistSheetPresented: Bool = false
    @State private var playlistPendingDelete: Playlist?
    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var selectedPlaylistIDs: Set<UUID> = []
    @State private var isBatchDeleteConfirmationPresented: Bool = false
    @State private var remotePlaylists: [Playlist] = []
    @State private var isLoadingRemotePlaylists: Bool = false

    init(
        playlistStore: PlaylistStore,
        localStore: LocalLibraryStore,
        playback: PlaybackController,
        subsonicServers: SubsonicServerStore? = nil,
        searchQuery: Binding<String> = .constant(""),
        selectedSourceID: Binding<String?> = .constant(nil),
        onSelectTrack: ((LocalTrack) -> Void)? = nil
    ) {
        self.playlistStore = playlistStore
        self.localStore = localStore
        self.playback = playback
        self.subsonicServers = subsonicServers
        self._searchQuery = searchQuery
        self._selectedSourceID = selectedSourceID
        self.onSelectTrack = onSelectTrack
    }

    private var isRemoteSourceActive: Bool {
        guard let selectedSourceID else { return false }
        return !SourceID.isLocalSourceID(selectedSourceID)
    }

    private var allPlaylists: [Playlist] {
        if isRemoteSourceActive {
            return remotePlaylists
        }
        return playlistStore.playlists
    }

    private var filteredPlaylists: [Playlist] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var matching = allPlaylists.filter { playlist in
            guard !query.isEmpty else { return true }
            let titleMatch = playlist.title.lowercased().contains(query)
            let descMatch = playlist.description?.lowercased().contains(query) ?? false
            return titleMatch || descMatch
        }

        if let selectedSourceID, !isRemoteSourceActive {
            matching = matching.filter { playlist in
                if SourceID.isLocalSourceID(selectedSourceID) {
                    return playlist.description?.contains("Subsonic") != true && playlist.description?.contains("极空间") != true
                } else {
                    return playlist.description?.contains("Subsonic") == true || playlist.description?.contains("极空间") == true
                }
            }
        }

        return matching.sorted { a, b in
            switch sortField {
            case .title:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .recentlyModified:
                return a.updatedAt > b.updatedAt
            case .songCount:
                return a.trackCount > b.trackCount
            }
        }
    }

    private func loadRemotePlaylists(sourceID: String) async {
        guard !SourceID.isLocalSourceID(sourceID), let serversStore = subsonicServers else {
            remotePlaylists = []
            return
        }
        let cleanID = SourceID(serverKeyOrSourceID: sourceID)
        guard let client = serversStore.client(for: cleanID),
              let server = serversStore.server(for: cleanID) else {
            return
        }

        isLoadingRemotePlaylists = true
        defer { isLoadingRemotePlaylists = false }

        do {
            let dtos = try await client.playlists()
            let mapped = dtos.map { pl -> Playlist in
                let key = "\(cleanID.serverKey):playlist:\(pl.id)"
                let digest = CryptoKit.SHA256.hash(data: Data(key.utf8))
                var bytes = Array(digest.prefix(16))
                bytes[6] = (bytes[6] & 0x0F) | 0x40
                bytes[8] = (bytes[8] & 0x3F) | 0x80
                let uuid = UUID(uuid: (
                    bytes[0], bytes[1], bytes[2], bytes[3],
                    bytes[4], bytes[5], bytes[6], bytes[7],
                    bytes[8], bytes[9], bytes[10], bytes[11],
                    bytes[12], bytes[13], bytes[14], bytes[15]
                ))
                let coverArtURL = (try? client.coverArtURL(id: pl.id))?.absoluteString
                return Playlist(
                    id: uuid,
                    title: pl.name,
                    description: "Subsonic · \(server.name) · [id:\(pl.id)]",
                    trackIDs: [],
                    artworkReference: coverArtURL,
                    isPinned: false
                )
            }
            self.remotePlaylists = mapped
        } catch is CancellationError {
            // Cancelled
        } catch {
            print("[PlaylistsView] Failed to load remote playlists: \(error)")
        }
    }

    private var activePlaylist: Playlist? {
        guard let id = selectedPlaylistID else { return nil }
        return playlistStore.playlists.first { $0.id == id }
            ?? remotePlaylists.first { $0.id == id }
            ?? fallbackSelectedPlaylist
    }

    private func selectPlaylist(_ playlist: Playlist) {
        fallbackSelectedPlaylist = playlist
        selectedPlaylistID = playlist.id
    }

    var body: some View {
        Group {
            if let playlist = activePlaylist {
                PlaylistDetailView(
                    playlistStore: playlistStore,
                    playlist: playlist,
                    tracks: selectedPlaylistTracks,
                    subsonicServers: subsonicServers,
                    playback: playback,
                    onBack: {
                        selectedPlaylistID = nil
                        fallbackSelectedPlaylist = nil
                    },
                    onSelectTrack: onSelectTrack
                )
            } else {
                overviewContent
            }
        }
        .task(id: "\(activePlaylist?.id.uuidString ?? "")|\(localStore.revision)") {
            guard let playlist = activePlaylist, !isRemoteSourceActive else {
                selectedPlaylistTracks = []
                return
            }
            let tracks = try? await localStore.resolvePlaylistTracks(playlist)
            guard !Task.isCancelled else { return }
            selectedPlaylistTracks = tracks ?? []
        }
        .task(id: selectedSourceID) {
            if isRemoteSourceActive, let sourceID = selectedSourceID {
                await loadRemotePlaylists(sourceID: sourceID)
            }
        }
    }

    // MARK: - Overview Content

    private var headerBar: some View {
        HStack(spacing: 12) {

            Spacer()

            // Sort Menu
            Picker(selection: $sortField) {
                ForEach(PlaylistSortField.allCases) { field in
                    Text(LocalizedStringKey(field.rawValue)).tag(field)
                }
            } label: {
                Label(LocalizedStringKey("Sort"), systemImage: "arrow.up.arrow.down")
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            // New Playlist Button
            Button {
                isNewPlaylistSheetPresented = true
            } label: {
                Label(LocalizedStringKey("New Playlist"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if !availableSources.isEmpty {
                SourceFilterBarView(sources: availableSources, selectedSourceID: $selectedSourceID)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                Divider()
            }

            if isLoadingRemotePlaylists && remotePlaylists.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在从远程媒体服务加载歌单...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPlaylists.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        MarqueeSelectionContainer(selectedIDs: $selectedPlaylistIDs) {
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
                                ],
                                spacing: 24
                            ) {
                                ForEach(filteredPlaylists) { playlist in
                                    playlistCard(playlist)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .hideScrollIndicatorsCompletely()
                .overlay(alignment: .bottom) {
                    if selectedPlaylistIDs.count > 1 {
                        floatingBatchBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedPlaylistIDs.count)
            }
        }
        .task {
            let localCount = playlistStore.playlists.filter { $0.description?.contains("Subsonic") != true && $0.description?.contains("极空间") != true }.count
            let remoteServers = subsonicServers?.servers ?? []

            var items = [
                SourceFilterItem(
                    id: nil,
                    displayName: "全部",
                    count: remoteServers.isEmpty ? localCount : nil
                )
            ]
            items.append(
                SourceFilterItem(
                    id: SourceID.defaultLocal.rawValue,
                    displayName: "本地歌单",
                    count: localCount
                )
            )
            for server in remoteServers {
                items.append(
                    SourceFilterItem(
                        id: server.id.rawValue,
                        displayName: server.name,
                        count: nil
                    )
                )
            }
            availableSources = items
        }
        .sheet(isPresented: $isNewPlaylistSheetPresented) {
            NewPlaylistSheetView { title, desc, rules in
                Task {
                    let created = await playlistStore.createPlaylist(title: title, description: desc, rules: rules)
                    selectPlaylist(created)
                }
            }
        }
        .confirmationDialog(
            LocalizedStringKey("Delete Playlist"),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            if let pending = playlistPendingDelete {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    Task {
                        await playlistStore.deletePlaylist(id: pending.id)
                        playlistPendingDelete = nil
                    }
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                playlistPendingDelete = nil
            }
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete this playlist? This action cannot be undone."))
        }
        .confirmationDialog(
            "Delete \(selectedPlaylistIDs.count) Playlists?",
            isPresented: $isBatchDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedPlaylistIDs.count) Playlists", role: .destructive) {
                let ids = selectedPlaylistIDs
                Task {
                    for id in ids {
                        await playlistStore.deletePlaylist(id: id)
                    }
                    selectedPlaylistIDs.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete these playlists? This action cannot be undone.")
        }
    }

    // MARK: - Playlist Card

    private func playlistCard(_ playlist: Playlist) -> some View {
        FoundationCard(
            aspectRatio: 1.0,
            cornerRadius: 10,
            isSelected: selectedPlaylistIDs.contains(playlist.id),
            onSelect: {
                SelectionHelper.handleTap(
                    for: playlist.id,
                    selectedIDs: $selectedPlaylistIDs,
                    allIDs: filteredPlaylists.map(\.id)
                )
            }
        ) {
            cardArtwork(for: playlist)
        } topTrailingBadges: {
            if playlist.isPinned {
                FoundationCardBadge("Pinned", systemImage: "pin.fill", foregroundStyle: Color.accentColor)
            }
            if playlist.isSmart {
                FoundationCardBadge("Smart", systemImage: "gearshape.fill", foregroundStyle: Color.purple)
            }
            if playlist.description?.contains("极空间") == true || playlist.description?.contains("Subsonic") == true {
                FoundationCardBadge("NAS", systemImage: "server.rack", foregroundStyle: Color.blue)
            }
        } actionOverlay: {
            FoundationCardActionButton(systemImage: "play.fill") {
                Task {
                    guard let resolved = try? await localStore.resolvePlaylistTracks(playlist),
                          let first = resolved.first else { return }
                    playback.play(first, queue: resolved)
                }
            }
        } title: {
            Text(playlist.title)
                .font(.headline)
                .lineLimit(1)
        } subtitle: {
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.isSmart ? "Smart playlist" : "\(playlist.trackCount) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let desc = playlist.description, desc.contains("来自") {
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            }
        }
        .marqueeItem(id: playlist.id)
        .onAppear {
            guard playlist.artworkReference == nil,
                  playlistArtworkRefs[playlist.id] == nil,
                  let firstID = playlist.trackIDs.first else { return }
            Task {
                if let track = try? await localStore.findTrack(id: firstID),
                   let reference = track.artworkReference {
                    playlistArtworkRefs[playlist.id] = reference
                }
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                selectPlaylist(playlist)
            }
        )
        .contextMenu {
            Button("Open Playlist") {
                selectPlaylist(playlist)
            }

            Button {
                Task {
                    guard let resolved = try? await localStore.resolvePlaylistTracks(playlist),
                          let first = resolved.first else { return }
                    playback.play(first, queue: resolved)
                }
            } label: {
                Label(LocalizedStringKey("Play"), systemImage: "play.fill")
            }
            .disabled(!playlist.isSmart && playlist.trackCount == 0)

            Divider()

            Button(role: .destructive) {
                playlistPendingDelete = playlist
                isDeleteConfirmationPresented = true
            } label: {
                Label(LocalizedStringKey("Delete Playlist"), systemImage: "trash")
            }
        }
    }

    // MARK: - Card Artwork

    @ViewBuilder
    private func cardArtwork(for playlist: Playlist) -> some View {
        let artworkRef = playlist.artworkReference ?? playlistArtworkRefs[playlist.id]

        if let artworkRef {
            MediaImageView(
                reference: artworkRef,
                thumbnailPixelSize: CGSize(width: 256, height: 256),
                placeholderSystemImage: "music.note.list",
                cornerRadius: 10
            )
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.7), Color.indigo.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note.list")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(searchQuery.isEmpty ? LocalizedStringKey("No Playlists Yet") : LocalizedStringKey("No Matching Playlists"))
                .font(.title3.weight(.medium))

            Text(searchQuery.isEmpty
                 ? LocalizedStringKey("Create your first custom playlist to organize your favorite songs.")
                 : LocalizedStringKey("Try changing your search terms."))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if searchQuery.isEmpty {
                Button {
                    isNewPlaylistSheetPresented = true
                } label: {
                    Label(LocalizedStringKey("Create Playlist"), systemImage: "plus")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedPlaylistIDs.count,
            title: "\(selectedPlaylistIDs.count) playlists",
            onDeselect: { selectedPlaylistIDs.removeAll() }
        ) {
            Button {
                let selected = filteredPlaylists.filter { selectedPlaylistIDs.contains($0.id) }
                Task {
                    var tracks: [LocalTrack] = []
                    for playlist in selected {
                        if let resolved = try? await localStore.resolvePlaylistTracks(playlist) {
                            tracks.append(contentsOf: resolved)
                        }
                    }
                    if let first = tracks.first { playback.play(first, queue: tracks) }
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredPlaylists.filter { selectedPlaylistIDs.contains($0.id) }
                Task {
                    for playlist in selected {
                        guard let tracks = try? await localStore.resolvePlaylistTracks(playlist) else { continue }
                        for track in tracks { playback.addToQueue(track) }
                    }
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                isBatchDeleteConfirmationPresented = true
            } label: {
                Label("Delete Playlists", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Previews

// MARK: - Smart Playlist Preset Option

enum SmartPlaylistPresetOption: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case favorites = "Favorites"
    case hiResAudio = "Hi-Res Audio"
    case losslessMasters = "Lossless Masters"

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .recentlyAdded: return LocalizedStringKey("Recently Added (Last 30 Days)")
        case .favorites: return LocalizedStringKey("Favorites")
        case .hiResAudio: return LocalizedStringKey("Hi-Res Audio (96kHz+ / 24-bit)")
        case .losslessMasters: return LocalizedStringKey("Lossless Masters (FLAC / ALAC / WAV)")
        }
    }

    func makeRuleGroup() -> SmartPlaylistRuleGroup {
        switch self {
        case .recentlyAdded: return PlaylistRuleEngine.Presets.recentlyAdded(days: 30)
        case .favorites: return PlaylistRuleEngine.Presets.favorites()
        case .hiResAudio: return PlaylistRuleEngine.Presets.hiResAudio()
        case .losslessMasters: return PlaylistRuleEngine.Presets.losslessMasters()
        }
    }
}

// MARK: - New Playlist Sheet View

@MainActor
struct NewPlaylistSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""
    var initialDescription: String = ""
    var initialRules: SmartPlaylistRuleGroup? = nil
    var onSave: (String, String?, SmartPlaylistRuleGroup?) -> Void

    @State private var title: String = ""
    @State private var playlistDescription: String = ""
    @State private var isSmartPlaylist: Bool = false
    @State private var selectedPreset: SmartPlaylistPresetOption = .recentlyAdded
    @State private var hasChangedPreset: Bool = false

    private static func detectPreset(from rules: SmartPlaylistRuleGroup?) -> SmartPlaylistPresetOption {
        guard let rules, let firstRule = rules.rules.first else { return .recentlyAdded }
        switch firstRule.field {
        case .isFavorite:
            return .favorites
        case .isHiRes:
            return .hiResAudio
        case .isLossless:
            return .losslessMasters
        case .addedAt:
            return .recentlyAdded
        default:
            return .recentlyAdded
        }
    }

    init(
        initialTitle: String = "",
        initialDescription: String = "",
        initialRules: SmartPlaylistRuleGroup? = nil,
        onSave: @escaping (String, String?, SmartPlaylistRuleGroup?) -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.initialRules = initialRules
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _playlistDescription = State(initialValue: initialDescription)
        let isSmart = initialRules != nil
        _isSmartPlaylist = State(initialValue: isSmart)
        _selectedPreset = State(initialValue: Self.detectPreset(from: initialRules))
    }

    var body: some View {
        NavigationStack {
            Form {
                if initialTitle.isEmpty {
                    Section {
                        Picker(LocalizedStringKey("Playlist Type"), selection: $isSmartPlaylist) {
                            Text(LocalizedStringKey("Standard Playlist")).tag(false)
                            Text(LocalizedStringKey("Smart Playlist")).tag(true)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text(LocalizedStringKey("Type"))
                    }
                }

                if isSmartPlaylist {
                    Section {
                        Picker(LocalizedStringKey("Smart Rule Preset"), selection: $selectedPreset) {
                            ForEach(SmartPlaylistPresetOption.allCases) { preset in
                                Text(preset.localizedTitle).tag(preset)
                            }
                        }
                        .onChange(of: selectedPreset) { _, newPreset in
                            hasChangedPreset = true
                            if title.isEmpty || SmartPlaylistPresetOption.allCases.map(\.rawValue).contains(title) {
                                title = newPreset.rawValue
                            }
                        }
                    } header: {
                        Text(LocalizedStringKey("Rule Definition"))
                    } footer: {
                        Text(LocalizedStringKey("Smart playlists dynamically update based on rules whenever your library changes."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField(LocalizedStringKey("Playlist Name"), text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField(LocalizedStringKey("Description (Optional)"), text: $playlistDescription, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(LocalizedStringKey("Details"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(initialTitle.isEmpty ? LocalizedStringKey("New Playlist") : LocalizedStringKey("Edit Playlist"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let desc = playlistDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        let rules: SmartPlaylistRuleGroup?
                        if isSmartPlaylist {
                            rules = hasChangedPreset ? selectedPreset.makeRuleGroup() : (initialRules ?? selectedPreset.makeRuleGroup())
                        } else {
                            rules = nil
                        }
                        onSave(trimmed, desc.isEmpty ? nil : desc, rules)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(minWidth: 360, minHeight: 280)
        }
    }
}

// MARK: - Feature

enum PlaylistsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "playlists",
                    group: "Library",
                    title: "Playlists",
                    systemImage: "music.note.list",
                    route: .section(.playlists),
                    order: 115
                )
            ],
            routes: [
                RouteContribution(
                    id: "playlists",
                    route: .section(.playlists)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "playlists",
                route: .section(.playlists)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Playlists"),
                        systemImage: "music.note.list"
                    ),
                    toolbar: playlistsToolbar
                ) { _ in
                    PlaylistsView(
                        playlistStore: scene.application.playlistStore,
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        subsonicServers: scene.application.subsonicServers,
                        searchQuery: Binding(
                            get: { scene.playlistsSearchQuery },
                            set: { scene.playlistsSearchQuery = $0 }
                        ),
                        selectedSourceID: Binding(
                            get: { scene.selectedSourceFilter },
                            set: { scene.selectedSourceFilter = $0 }
                        ),
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        }
                    )
                }
            }
        ]
    }

    // MARK: - Workspace Toolbar

    private static var playlistsToolbar: ToolbarPresentation<SceneModel> {
        ToolbarPresentation(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "playlists.search",
                        prompt: String(localized: "Search Playlists"),
                        text: { scene in
                            scene.playlistsSearchQuery
                        },
                        update: { scene, value in
                            scene.playlistsSearchQuery = value
                        }
                    )
                )
            ]
        )
    }
}



// MARK: - Previews

#Preview("Playlists Overview") {
    let playback = MSRUPreviewData.makePlaybackController()
    let localStore = MSRUPreviewData.makeLocalLibraryStore()
    let playlistStore = PlaylistStore(repository: PreviewPlaylistRepository(playlists: [
        Playlist(
            title: "Favorites",
            description: "Top rated local tracks",
            trackIDs: MSRUPreviewData.localTracks.prefix(3).map(\.id),
            isPinned: true
        ),
        Playlist(
            title: "Chill & Ambient",
            description: "Relaxing late night focus music",
            trackIDs: MSRUPreviewData.localTracks.suffix(2).map(\.id)
        )
    ]))

    PlaylistsView(
        playlistStore: playlistStore,
        localStore: localStore,
        playback: playback
    )
    .frame(width: 800, height: 600)
}

#Preview("New Playlist Sheet") {
    NewPlaylistSheetView(
        initialTitle: "Favorites",
        initialDescription: "Top favorite tracks",
        onSave: { title, desc, rules in
            print("Saved playlist:", title, desc ?? "", rules != nil)
        }
    )
}
