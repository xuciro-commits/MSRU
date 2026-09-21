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

    private var overviewContent: some View {
        VStack(spacing: 0) {
            // Header Bar
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

            Divider()

            // Playlists Grid / Empty
            if filteredPlaylists.isEmpty {
                emptyView
            } else {
                ScrollView {
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
                    .padding(24)
                }
                .hideScrollIndicatorsCompletely()
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
    }

    // MARK: - Playlist Card

    private func playlistCard(_ playlist: Playlist) -> some View {
        FoundationCard(
            aspectRatio: 1.0,
            cornerRadius: 10,
            isSelected: selectedPlaylist?.id == playlist.id,
            onSelect: { selectedPlaylist = playlist }
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
        .contextMenu {
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
        // Find first track's artwork if available
        let firstTrackArtwork = playlist.trackIDs.lazy.compactMap { id in
            localStore.tracks.first { $0.id == id }?.artworkData
        }.first

        if let data = firstTrackArtwork, let image = Image(artworkData: data) {
            image
                .resizable()
                .scaledToFill()
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
        .padding(32)
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
