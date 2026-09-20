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

    private var allArtists: [ArtistPresentationModel] {
        LibraryPresentationAggregator.buildArtists(from: localStore.tracks)
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
            "确认删除艺术家「\(artistPendingDelete?.name ?? "")」？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("级联删除该艺术家及全部内容", role: .destructive) {
                if let toDelete = artistPendingDelete {
                    Task {
                        await localStore.deleteArtist(name: toDelete.name)
                        if selectedArtist?.id == toDelete.id {
                            selectedArtist = nil
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将执行级联删除，同时从本地资料库中移除该艺术家的所有专辑与全部歌曲。")
        }
    }

    private var mainArtistsGrid: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if filteredArtists.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 28)],
                        spacing: 32
                    ) {
                        ForEach(filteredArtists) { artist in
                            ArtistAvatarView(
                                artist: artist,
                                onSelect: {
                                    selectedArtist = artist
                                }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    artistPendingDelete = artist
                                    isDeleteConfirmationPresented = true
                                } label: {
                                    Label("删除艺术家 (级联删除)", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(28)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("艺术家")
                    .font(.largeTitle.bold())

                Text("\(allArtists.count) 位艺术家")
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

                TextField("筛选艺术家…", text: $searchQuery)
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

            Text("未找到艺术家")
                .font(.headline)

            Text("导入音乐后，你喜爱的艺术家会显示在这里。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
