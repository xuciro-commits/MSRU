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

        var displayTitle: String {
            switch self {
            case .title: return "标题"
            case .artist: return "艺术家"
            case .year: return "年份"
            }
        }
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
                .scrollIndicators(.hidden)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("专辑")
                    .font(.largeTitle.bold())

                Text("\(allAlbums.count) 张专辑")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("筛选专辑…", text: $searchQuery)
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
                Picker("排序", selection: $sortField) {
                    ForEach(AlbumSortField.allCases) { field in
                        Text(field.displayTitle).tag(field)
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

            Text("未找到专辑")
                .font(.headline)

            Text("导入音乐或调整搜索条件以查看专辑资料库。")
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
