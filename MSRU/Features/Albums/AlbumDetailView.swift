//
//  AlbumDetailView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

struct AlbumDetailView: View {
    let album: AlbumPresentationModel
    let localTracks: [LocalTrack]
    @Bindable var playback: PlaybackController
    let onBack: () -> Void
    let onSelectTrack: (LocalTrack) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Back button & breadcrumb
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.backward")
                        Text("专辑")
                    }
                    .font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Hero Header
                HStack(alignment: .bottom, spacing: 24) {
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 180, height: 180)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

                        if let badge = album.audioQualityBadge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                            Text("专辑")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(album.title)
                            .font(.system(size: 32, weight: .bold))
                            .lineLimit(2)

                        Text(album.artist)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            if let year = album.year {
                                Text("\(year)")
                                Text("•")
                            }
                            Text("\(album.trackCount) 首歌曲，\(album.formattedDuration)")
                        }
                        .font(.callout)
                        .foregroundStyle(.tertiary)

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
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                // Track Lists by Discs
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(album.discs) { disc in
                        if album.discs.count > 1 {
                            Text(disc.discTitle ?? "第 \(disc.discNumber) 张碟")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 2) {
                            ForEach(disc.tracks) { trackModel in
                                trackRow(trackModel)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func trackRow(_ trackModel: TrackPresentationModel) -> some View {
        let matchingLocal = localTracks.first { $0.id == trackModel.id }
        let isCurrent = matchingLocal != nil && playback.currentTrack?.id == matchingLocal?.id
        let isPlaying = isCurrent && playback.isPlaying

        return HStack(spacing: 14) {
            Text("\(trackModel.trackNumber)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(trackModel.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(1)

                if trackModel.artist != album.artist {
                    Text(trackModel.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let badge = trackModel.formatBadge {
                Text(badge)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            Text(trackModel.formattedDuration)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                if let local = matchingLocal {
                    playback.toggle(track: local, queue: localTracks)
                }
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
            if let local = matchingLocal {
                onSelectTrack(local)
            }
        }
        .contextMenu {
            if let local = matchingLocal {
                Button("下一首播放") {
                    playback.playNext(local)
                }
                Button("加入队列") {
                    playback.addToQueue(local)
                }
            }
        }
    }

    private func playAll() {
        guard let first = localTracks.first else { return }
        playback.play(first)
    }

    private func shuffleAll() {
        guard let first = localTracks.shuffled().first else { return }
        playback.play(first)
    }
}

// MARK: - Preview

#Preview("Album Detail View") {
    let scene = MSRUPreviewData.makeScene(section: .albums)
    AlbumDetailView(
        album: AlbumPresentationModel(
            id: "preview-album",
            title: "叶惠美",
            artist: "周杰伦",
            year: 2003,
            trackCount: 2,
            duration: 520,
            audioQualityBadge: "Hi-Res 24/96",
            discs: [
                DiscTrackGroup(
                    discNumber: 1,
                    tracks: [
                        TrackPresentationModel(id: "1", trackNumber: 1, title: "以父之名", artist: "周杰伦", duration: 342, formatBadge: "FLAC"),
                        TrackPresentationModel(id: "2", trackNumber: 2, title: "晴天", artist: "周杰伦", duration: 269, formatBadge: "FLAC")
                    ]
                )
            ]
        ),
        localTracks: [],
        playback: scene.application.playback,
        onBack: {},
        onSelectTrack: { _ in }
    )
    .frame(width: 700, height: 600)
}
