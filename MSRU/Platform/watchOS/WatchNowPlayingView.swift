//
//  WatchNowPlayingView.swift
//  MSRU
//

import SwiftUI
import Observation

// MARK: - Watch Now Playing View

/// Native watchOS short-task presentation conforming to InteractionAtlas Section 19.1.
/// Features wrist-optimized touch targets, high-fidelity badges, transport controls, and queue sheet.
@MainActor
struct WatchNowPlayingView: View {

    @Bindable var playback: PlaybackController
    @State private var isQueuePresented = false
    @State private var isVolumeSheetPresented = false

    var body: some View {
        VStack(spacing: 4) {
            headerInfo
                .padding(.top, 2)

            artworkAndProgress
                .padding(.vertical, 2)

            transportControls
                .padding(.vertical, 4)

            bottomToolbar
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .sheet(isPresented: $isQueuePresented) {
            WatchQueueSheetView(
                playback: playback,
                onClose: { isQueuePresented = false }
            )
        }
        .sheet(isPresented: $isVolumeSheetPresented) {
            volumeSheet
        }
    }

    // MARK: - Header Info

    private var headerInfo: some View {
        VStack(spacing: 1) {
            if let format = playback.audioFormatInfo {
                Text(format.isHiRes ? "HI-RES" : (format.isLossless ? "LOSSLESS" : format.codec.uppercased()))
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.25))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }

            Text(LocalizedStringKey(playback.unifiedTitle))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(LocalizedStringKey(playback.unifiedSubtitle))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Artwork & Progress

    private var artworkAndProgress: some View {
        VStack(spacing: 4) {
            MediaImageView(
                reference: playback.unifiedArtworkReference,
                fixedSize: CGSize(width: 44, height: 44),
                thumbnailPixelSize: CGSize(width: 88, height: 88),
                cornerRadius: 8
            )
            .shadow(radius: 2)

            // Compact Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(playback.progress))), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 16) {
            Button {
                playback.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                playback.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 40)
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Button {
                playback.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Button {
                isQueuePresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                isVolumeSheetPresented = true
            } label: {
                Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Volume Sheet

    private var volumeSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)

                Slider(
                    value: Binding(
                        get: { playback.volume },
                        set: { playback.setVolume($0) }
                    ),
                    in: 0.0...1.0
                )
                .tint(Color.accentColor)
                .padding(.horizontal, 16)

                Button {
                    playback.toggleMute()
                } label: {
                    Text(playback.isMuted ? LocalizedStringKey("Unmute") : LocalizedStringKey("Mute"))
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
            }
            .navigationTitle(LocalizedStringKey("Volume"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) {
                        isVolumeSheetPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Watch Now Playing · 41mm") {
    let playback = MSRUPreviewData.makePlaybackController()
    WatchNowPlayingView(playback: playback)
        .frame(width: 198, height: 242)
}

#Preview("Watch Now Playing · 45mm") {
    let playback = MSRUPreviewData.makePlaybackController()
    WatchNowPlayingView(playback: playback)
        .frame(width: 210, height: 260)
}

#Preview("Watch Queue") {
    WatchQueueSheetView(playback: MSRUPreviewData.makePlaybackController(), onClose: {})
        .frame(width: 210, height: 260)
}

// MARK: - Watch Queue Sheet View

@MainActor
struct WatchQueueSheetView: View {
    @Bindable var playback: PlaybackController
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if playback.playbackQueue.current == nil && playback.playbackQueue.upcoming.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("Queue is empty"),
                        systemImage: "music.note.list"
                    )
                } else {
                    List {
                        if let current = playback.playbackQueue.current {
                            Section(LocalizedStringKey("Now Playing")) {
                                queueRow(current, isCurrent: true)
                            }
                        }

                        if !playback.playbackQueue.upcoming.isEmpty {
                            Section(LocalizedStringKey("Up Next")) {
                                ForEach(playback.playbackQueue.upcoming) { item in
                                    queueRow(item, isCurrent: false)
                                }
                            }

                            Section {
                                Button(role: .destructive) {
                                    playback.clearUpcoming()
                                } label: {
                                    HStack {
                                        Spacer()
                                        Label(LocalizedStringKey("Clear Queue"), systemImage: "trash")
                                            .font(.footnote)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Queue"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) {
                        onClose()
                    }
                }
            }
        }
    }

    private func queueRow(_ queued: PlaybackQueueItem, isCurrent: Bool) -> some View {
        let item = queued.item
        return Button {
            if isCurrent {
                playback.toggle()
            } else {
                playback.playQueuedItem(id: queued.id)
                onClose()
            }
        } label: {
            HStack(spacing: 8) {
                if isCurrent {
                    Image(systemName: playback.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
