//
//  PlaylistsView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

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
    let playback: PlaybackController
    var onSelectTrack: ((LocalTrack) -> Void)?

    @State private var searchQuery: String = ""
    @State private var sortField: PlaylistSortField = .title
    @State private var selectedPlaylist: Playlist?
    @State private var isNewPlaylistSheetPresented: Bool = false
    @State private var playlistPendingDelete: Playlist?
    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var selectedPlaylistIDs: Set<UUID> = []
    @State private var isBatchDeleteConfirmationPresented: Bool = false

    private var filteredPlaylists: [Playlist] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = playlistStore.playlists.filter { playlist in
            guard !query.isEmpty else { return true }
            let titleMatch = playlist.title.lowercased().contains(query)
            let descMatch = playlist.description?.lowercased().contains(query) ?? false
            return titleMatch || descMatch
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

    var body: some View {
        Group {
            if let playlist = selectedPlaylist {
                PlaylistDetailView(
                    playlistStore: playlistStore,
                    playlist: playlist,
                    tracks: localStore.tracks,
                    playback: playback,
                    onBack: { selectedPlaylist = nil },
                    onSelectTrack: onSelectTrack
                )
            } else {
                overviewContent
            }
        }
    }

    // MARK: - Overview Content

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(LocalizedStringKey("Search Playlists"), text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 240)

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
        Group {
            if filteredPlaylists.isEmpty {
                VStack(spacing: 0) {
                    headerBar
                    Divider()
                    emptyView
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        headerBar
                        Divider()

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
        .sheet(isPresented: $isNewPlaylistSheetPresented) {
            NewPlaylistSheetView { title, desc in
                Task {
                    let created = await playlistStore.createPlaylist(title: title, description: desc)
                    selectedPlaylist = created
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
        } actionOverlay: {
            FoundationCardActionButton(systemImage: "play.fill") {
                let resolved = playlist.trackIDs.compactMap { id in
                    localStore.tracks.first { $0.id == id }
                }
                if let first = resolved.first {
                    playback.play(first, queue: resolved)
                }
            }
        } title: {
            Text(playlist.title)
                .font(.headline)
                .lineLimit(1)
        } subtitle: {
            Text("\(playlist.trackCount) songs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .marqueeItem(id: playlist.id)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                selectedPlaylist = playlist
            }
        )
        .contextMenu {
            Button("Open Playlist") {
                selectedPlaylist = playlist
            }

            Button {
                let resolved = playlist.trackIDs.compactMap { id in
                    localStore.tracks.first { $0.id == id }
                }
                if let first = resolved.first {
                    playback.play(first, queue: resolved)
                }
            } label: {
                Label(LocalizedStringKey("Play"), systemImage: "play.fill")
            }
            .disabled(playlist.trackCount == 0)

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
        let artworkRef = playlist.artworkReference ?? playlist.trackIDs.lazy.compactMap { id in
            localStore.tracks.first { $0.id == id }?.artworkReference
        }.first

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
                let tracks = selected.flatMap { playlist in
                    playlist.trackIDs.compactMap { id in
                        localStore.tracks.first { $0.id == id }
                    }
                }
                if let first = tracks.first {
                    playback.play(first, queue: tracks)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredPlaylists.filter { selectedPlaylistIDs.contains($0.id) }
                let tracks = selected.flatMap { playlist in
                    playlist.trackIDs.compactMap { id in
                        localStore.tracks.first { $0.id == id }
                    }
                }
                for t in tracks {
                    playback.addToQueue(t)
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

// MARK: - New Playlist Sheet View

@MainActor
struct NewPlaylistSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""
    var initialDescription: String = ""
    var onSave: (String, String?) -> Void

    @State private var title: String = ""
    @State private var playlistDescription: String = ""

    init(
        initialTitle: String = "",
        initialDescription: String = "",
        onSave: @escaping (String, String?) -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _playlistDescription = State(initialValue: initialDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                        onSave(trimmed, desc.isEmpty ? nil : desc)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(minWidth: 320, minHeight: 220)
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
                    )
                ) { _ in
                    PlaylistsView(
                        playlistStore: scene.application.playlistStore,
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        }
                    )
                }
            }
        ]
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
        onSave: { title, desc in
            print("Saved playlist:", title, desc ?? "")
        }
    )
}

