//
//  ArtistsView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

struct ArtistsView: View {
    @Bindable var localStore: LocalLibraryStore
    @Bindable var playback: PlaybackController
    let onSelectTrack: (LocalTrack) -> Void
    var onAddMusic: (() -> Void)? = nil

    @State private var searchQuery: String = ""
    @State private var selectedArtist: ArtistPresentationModel?
    @State private var selectedAlbum: AlbumPresentationModel?
    @State private var artistPendingDelete: ArtistPresentationModel?
    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var selectedArtistIDs: Set<String> = []
    @State private var isBatchDeleteConfirmationPresented: Bool = false

    private var allArtists: [ArtistPresentationModel] {
        localStore.artists
    }

    private var filteredArtists: [ArtistPresentationModel] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allArtists }
        return allArtists.filter {
            $0.name.lowercased().contains(query) ||
            $0.aliases.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        Group {
            if let album = selectedAlbum {
                let albumTracks = localStore.tracks.filter {
                    ($0.album?.trimmingCharacters(in: .whitespacesAndNewlines) == album.title) ||
                    ($0.artist.trimmingCharacters(in: .whitespacesAndNewlines) == album.artist)
                }

                AlbumDetailView(
                    album: album,
                    localTracks: albumTracks,
                    playback: playback,
                    onBack: { selectedAlbum = nil },
                    onSelectTrack: onSelectTrack
                )
            } else if let artist = selectedArtist {
                let artistTracks = localStore.tracks.filter {
                    $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) == artist.name
                }

                ArtistDetailView(
                    artist: artist,
                    tracks: artistTracks,
                    playback: playback,
                    onBack: { selectedArtist = nil },
                    onSelectTrack: onSelectTrack,
                    onSelectAlbum: { album in
                        selectedAlbum = album
                    },
                    onDeleteArtist: {
                        artistPendingDelete = artist
                        isDeleteConfirmationPresented = true
                    }
                )
            } else {
                mainArtistsGrid
            }
        }
        .confirmationDialog(
            "Delete artist \"\(artistPendingDelete?.name ?? "")\"?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete artist and all content", role: .destructive) {
                if let toDelete = artistPendingDelete {
                    Task {
                        await localStore.deleteArtist(name: toDelete.name)
                        if selectedArtist?.id == toDelete.id {
                            selectedArtist = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all albums and songs of this artist from the local library.")
        }
        .confirmationDialog(
            "Delete \(selectedArtistIDs.count) artists?",
            isPresented: $isBatchDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete \(selectedArtistIDs.count) artists and all content", role: .destructive) {
                let toDelete = filteredArtists.filter { selectedArtistIDs.contains($0.id) }
                Task {
                    for artist in toDelete {
                        await localStore.deleteArtist(name: artist.name)
                    }
                    selectedArtistIDs.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all albums and songs of the selected artists from the local library.")
        }
    }

    @ViewBuilder
    private var mainArtistsGrid: some View {
        if localStore.isLoading {
            VStack(spacing: 0) {
                header
                Divider()
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if filteredArtists.isEmpty {
            VStack(spacing: 0) {
                header
                Divider()
                emptyState
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    Divider()

                    MarqueeSelectionContainer(selectedIDs: $selectedArtistIDs) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 24)],
                            spacing: 28
                        ) {
                            ForEach(filteredArtists) { artist in
                                ArtistAvatarView(
                                    artist: artist,
                                    isSelected: selectedArtistIDs.contains(artist.id),
                                    onSelect: {
                                        SelectionHelper.handleTap(
                                            for: artist.id,
                                            selectedIDs: $selectedArtistIDs,
                                            allIDs: filteredArtists.map(\.id)
                                        )
                                    }
                                ) {
                                    ArtworkThumbnailView(
                                        reference: artist.artworkReference,
                                        thumbnailPixelSize: CGSize(width: 240, height: 240),
                                        placeholderSystemImage: "music.mic",
                                        isCircular: true
                                    )
                                }
                                .marqueeItem(id: artist.id)
                                .simultaneousGesture(
                                    TapGesture(count: 2).onEnded {
                                        selectedArtist = artist
                                    }
                                )
                                .contextMenu {
                                    Button("Open Artist") { selectedArtist = artist }
                                    Button("Play Artist") { playArtist(artist) }
                                    Divider()
                                    Button(role: .destructive) {
                                        artistPendingDelete = artist
                                        isDeleteConfirmationPresented = true
                                    } label: {
                                        Label("Delete Artist (Cascade)", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(28)
            }
            .hideScrollIndicatorsCompletely()
            .overlay(alignment: .bottom) {
                if selectedArtistIDs.count > 1 {
                    floatingBatchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedArtistIDs.count)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Artists")
                    .font(.largeTitle.bold())

                Text("\(allArtists.count) Artists")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onAddMusic {
                Button {
                    onAddMusic()
                } label: {
                    Label("Add Music", systemImage: "plus")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Filter artists…", text: $searchQuery)
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
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .frame(width: 260)

            HStack {
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.mic")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("No artists found")
                .font(.headline)

            Text("Imported artists will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func playArtist(_ artist: ArtistPresentationModel) {
        let matching = localStore.tracks.filter {
            $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) == artist.name
        }
        if let first = matching.first {
            playback.toggle(track: first, queue: matching)
        }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedArtistIDs.count,
            title: "\(selectedArtistIDs.count) artists",
            onDeselect: { selectedArtistIDs.removeAll() }
        ) {
            Button {
                let selected = filteredArtists.filter { selectedArtistIDs.contains($0.id) }
                let tracks = localStore.tracks.filter { t in
                    selected.contains { $0.name == t.artist.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                if let first = tracks.first {
                    playback.toggle(track: first, queue: tracks)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredArtists.filter { selectedArtistIDs.contains($0.id) }
                let tracks = localStore.tracks.filter { t in
                    selected.contains { $0.name == t.artist.trimmingCharacters(in: .whitespacesAndNewlines) }
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
                Label("Delete Artists", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Feature

enum ArtistsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "artists",
                    group: "Library",
                    title: "Artists",
                    systemImage: "music.mic",
                    route: .section(.artists),
                    order: 120
                )
            ],
            routes: [
                RouteContribution(
                    id: "artists",
                    route: .section(.artists)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "artists",
                route: .section(.artists)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Artists"),
                        systemImage: "music.mic"
                    )
                ) { _ in
                    ArtistsView(
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        },
                        onAddMusic: {
                            scene.send(.navigate(.section(.addMusic)))
                        }
                    )
                }
            }
        ]
    }
}



// MARK: - Preview

#Preview("Artists View") {
    let scene = MSRUPreviewData.makeScene(section: .artists)
    ArtistsView(
        localStore: scene.application.localLibrary,
        playback: scene.application.playback,
        onSelectTrack: { _ in }
    )
    .frame(width: 800, height: 600)
}

