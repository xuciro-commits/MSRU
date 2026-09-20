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

    @State private var searchQuery: String = ""
    @State private var selectedArtist: ArtistPresentationModel?
    @State private var selectedAlbum: AlbumPresentationModel?

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
                    }
                )
            } else {
                mainArtistsGrid
            }
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
