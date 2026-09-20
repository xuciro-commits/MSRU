//
//  ArtistDetailView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

struct ArtistDetailView: View {
    let artist: ArtistPresentationModel
    let tracks: [LocalTrack]
    @Bindable var playback: PlaybackController
    let onBack: () -> Void
    let onSelectTrack: (LocalTrack) -> Void
    let onSelectAlbum: (AlbumPresentationModel) -> Void
    var onDeleteArtist: (() -> Void)? = nil

    @State private var isDeleteConfirmationPresented: Bool = false

    private var albums: [AlbumPresentationModel] {
        LibraryPresentationAggregator.buildAlbums(from: tracks).filter {
            $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) == artist.name
        }
    }

    private var topTracks: [LocalTrack] {
        Array(tracks.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Back button & breadcrumb
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.backward")
                        Text("艺术家")
                    }
                    .font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Hero Header
                HStack(alignment: .center, spacing: 24) {
                    artistArtworkView
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("艺术家")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(artist.name)
                            .font(.system(size: 36, weight: .bold))
                            .lineLimit(1)

                        // Aliases tags
                        if !artist.aliases.isEmpty {
                            HStack(spacing: 6) {
                                Text("别名：")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                ForEach(artist.aliases, id: \.self) { alias in
                                    Text(alias)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        }

                        Text(artist.displaySubtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button(action: playAll) {
                                Label("播放", systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: shuffleAll) {
                                Label("随机播放", systemImage: "shuffle")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)

                            if onDeleteArtist != nil {
                                Button(role: .destructive, action: { isDeleteConfirmationPresented = true }) {
                                    Label("删除艺术家", systemImage: "trash")
                                        .font(.headline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                // Top Tracks Section
                if !topTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门歌曲")
                            .font(.title2.bold())
                            .padding(.horizontal, 24)

                        VStack(spacing: 2) {
                            ForEach(Array(topTracks.enumerated()), id: \.element.id) { index, track in
                                trackRow(track, number: index + 1)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Discography Section
                if !albums.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("专辑")
                            .font(.title2.bold())
                            .padding(.horizontal, 24)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)],
                            spacing: 24
                        ) {
                            ForEach(albums) { album in
                                AlbumCardView(
                                    album: album,
                                    onSelect: {
                                        onSelectAlbum(album)
                                    },
                                    onPlay: {
                                        if let first = tracks.first(where: { $0.album == album.title }) {
                                            playback.play(first)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(
            "确认删除艺术家「\(artist.name)」？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("级联删除该艺术家及名下全部内容", role: .destructive) {
                onDeleteArtist?()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将执行级联删除，同时从本地资料库中移除该艺术家的所有专辑与全部歌曲。该操作不可撤销。")
        }
    }

    private func trackRow(_ track: LocalTrack, number: Int) -> some View {
        let isCurrent = playback.currentTrack?.id == track.id
        let isPlaying = isCurrent && playback.isPlaying

        return HStack(spacing: 14) {
            Text("\(number)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(1)

                if let album = track.album {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatDuration(track.duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                playback.toggle(track: track, queue: tracks)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption)
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectTrack(track)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let min = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", min, sec)
    }

    private func playAll() {
        guard let first = tracks.first else { return }
        playback.play(first)
    }

    private func shuffleAll() {
        guard let first = tracks.shuffled().first else { return }
        playback.play(first)
    }

    @ViewBuilder
    private var artistArtworkView: some View {
        if let data = artist.artworkData, let image = Image(artworkData: data) {
            image
                .resizable()
                .scaledToFill()
        } else if let url = artist.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderArtistView
                @unknown default:
                    placeholderArtistView
                }
            }
        } else {
            placeholderArtistView
        }
    }

    private var placeholderArtistView: some View {
        Circle()
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
    }
}

// MARK: - Preview

#Preview("Artist Detail View") {
    let scene = MSRUPreviewData.makeScene(section: .artists)
    ArtistDetailView(
        artist: ArtistPresentationModel(
            id: "preview-artist",
            name: "周杰伦",
            aliases: ["Jay Chou", "周董"],
            country: "TW",
            albumCount: 2,
            trackCount: 20
        ),
        tracks: [],
        playback: scene.application.playback,
        onBack: {},
        onSelectTrack: { _ in },
        onSelectAlbum: { _ in }
    )
    .frame(width: 800, height: 600)
}
