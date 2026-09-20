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

    enum AlbumSortField: String, CaseIterable, Identifiable {
        case title = "Title"
        case artist = "Artist"
        case year = "Year"

        var id: String { rawValue }
    }

    @State private var searchQuery: String = ""
    @State private var sortField: AlbumSortField = .title
    @State private var selectedAlbum: AlbumPresentationModel?

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
                    onSelectTrack: onSelectTrack
                )
            } else {
                mainAlbumsGrid
            }
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
                        columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 24)],
                        spacing: 28
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
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Albums")
                    .font(.largeTitle.bold())

                Text("\(allAlbums.count) albums")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Filter albums...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 140)

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

            Picker("Sort", selection: $sortField) {
                ForEach(AlbumSortField.allCases) { field in
                    Text(field.rawValue).tag(field)
                }
            }
            .frame(width: 110)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("No Albums Found")
                .font(.headline)

            Text("Import music or adjust search filters to view your album library.")
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
