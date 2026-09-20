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
            case .title: return "标题"
            case .artist: return "艺术家"
            case .year: return "年份"
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
            "确认删除专辑「\(albumPendingDelete?.title ?? "")」？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("级联删除该专辑及全部歌曲", role: .destructive) {
                if let toDelete = albumPendingDelete {
                    Task {
                        await localStore.deleteAlbum(title: toDelete.title, artist: toDelete.artist)
                        if selectedAlbum?.id == toDelete.id {
                            selectedAlbum = nil
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将执行级联删除，从本地资料库中移除该专辑名下的全部歌曲。")
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
                            .contextMenu {
                                Button("播放专辑") { playAlbum(album) }
                                Divider()
                                Button(role: .destructive) {
                                    albumPendingDelete = album
                                    isDeleteConfirmationPresented = true
                                } label: {
                                    Label("删除专辑 (级联删除)", systemImage: "trash")
                                }
                            }
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

            if let onAddMusic {
                Button {
                    onAddMusic()
                } label: {
                    Label("添加音乐", systemImage: "plus")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

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
