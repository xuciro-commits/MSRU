//
//  AlbumsView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

struct AlbumsView: View {
    @Bindable var localStore: LocalLibraryStore
    @Bindable var playback: PlaybackController
    let onSelectTrack: (LocalTrack) -> Void
    var onAddMusic: (() -> Void)? = nil

    enum AlbumSortField: String, CaseIterable, Identifiable {
        case title = "Title"
        case artist = "Artist"
        case year = "Year"

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .title: return "Title"
            case .artist: return "Artist"
            case .year: return "Year"
            }
        }
    }

    @State private var searchQuery: String = ""
    @State private var sortField: AlbumSortField = .title
    @State private var selectedAlbum: AlbumPresentationModel?
    @State private var albumPendingDelete: AlbumPresentationModel?
    @State private var isDeleteConfirmationPresented: Bool = false

    private var allAlbums: [AlbumPresentationModel] {
        LibraryPresentationAggregator.buildAlbums(from: localStore.tracks)
    }

    private var filteredAlbums: [AlbumPresentationModel] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = allAlbums.filter { album in
            guard !query.isEmpty else { return true }
            return album.title.lowercased().contains(query) || album.artist.lowercased().contains(query)
        }

        return matching.sorted { a, b in
            switch sortField {
            case .title:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .artist:
                return a.artist.localizedCaseInsensitiveCompare(b.artist) == .orderedAscending
            case .year:
                return (a.year ?? 0) > (b.year ?? 0)
            }
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
                    onSelectTrack: onSelectTrack,
                    onDeleteAlbum: {
                        albumPendingDelete = album
                        isDeleteConfirmationPresented = true
                    }
                )
            } else {
                mainAlbumsGrid
            }
        }
        .confirmationDialog(
            "Delete album \"\(albumPendingDelete?.title ?? "")\"?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete album and all songs", role: .destructive) {
                if let toDelete = albumPendingDelete {
                    Task {
                        await localStore.deleteAlbum(title: toDelete.title, artist: toDelete.artist)
                        if selectedAlbum?.id == toDelete.id {
                            selectedAlbum = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all songs under this album from the local library.")
        }
    }

    private var mainAlbumsGrid: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if filteredAlbums.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)],
                        spacing: 24
                    ) {
                        ForEach(filteredAlbums) { album in
                            AlbumCardView(
                                album: album,
                                onSelect: {
                                    selectedAlbum = album
                                },
                                onPlay: {
                                    playAlbum(album)
                                }
                            ) {
                                ArtworkThumbnailView(
                                    reference: album.artworkReference,
                                    thumbnailPixelSize: CGSize(width: 240, height: 240),
                                    placeholderSystemImage: "square.stack",
                                    cornerRadius: 10
                                )
                            }
                            .contextMenu {
                                Button("Play Album") { playAlbum(album) }
                                Divider()
                                Button(role: .destructive) {
                                    albumPendingDelete = album
                                    isDeleteConfirmationPresented = true
                                } label: {
                                    Label("Delete Album (Cascade)", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .hideScrollIndicatorsCompletely()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Albums")
                    .font(.largeTitle.bold())

                Text("\(allAlbums.count) Albums")
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

                TextField("Filter albums…", text: $searchQuery)
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
                Picker("Sort", selection: $sortField) {
                    ForEach(AlbumSortField.allCases) { field in
                        Text(LocalizedStringKey(field.rawValue)).tag(field)
                    }
                }
                .frame(width: 110)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("No albums found")
                .font(.headline)

            Text("Import music or adjust search terms to see albums.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func playAlbum(_ album: AlbumPresentationModel) {
        let matching = localStore.tracks.filter {
            ($0.album?.trimmingCharacters(in: .whitespacesAndNewlines) == album.title) ||
            ($0.artist.trimmingCharacters(in: .whitespacesAndNewlines) == album.artist)
        }
        if let first = matching.first {
            playback.play(first)
        }
    }
}

// MARK: - Preview

#Preview("Albums View") {
    let scene = MSRUPreviewData.makeScene(section: .albums)
    AlbumsView(
        localStore: scene.application.localLibrary,
        playback: scene.application.playback,
        onSelectTrack: { _ in }
    )
    .frame(width: 800, height: 600)
}
