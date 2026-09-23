//
//  MenuBarPlayerView.swift
//  MSRU
//
//  macOS MenuBarExtra Status Item & Mini Controller
//

#if os(macOS)

import MusicLibrary
import MusicPlayback
import SwiftUI
import AppKit
import AppFoundation
import AppFoundationUI

// MARK: - Menu Bar Status Item Label

struct MenuBarStatusItemLabel: View {
    let playback: PlaybackController

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: playback.isPlaying ? "waveform" : "music.note")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

// MARK: - Menu Bar Player Window View

struct MenuBarPlayerView: View {
    var playback: PlaybackController

    var onOpenMainWindow: (() -> Void)? = nil
    var onQuitApp: (() -> Void)? = nil

    @State private var scrubbingProgress: Double? = nil
    @State private var isScrubbing: Bool = false

    private var effectiveProgress: Double {
        if let preview = scrubbingProgress {
            return preview
        }
        guard playback.duration > 0 else { return 0.0 }
        return min(max(playback.currentTime / playback.duration, 0.0), 1.0)
    }

    var body: some View {
        VStack(spacing: 12) {
            headerSection

            if playback.unifiedHasTrack {
                if !playback.isLiveStream {
                    scrubberSection
                }

                transportSection

                volumeSection
            }

            Divider()
                .opacity(0.4)

            footerSection
        }
        .padding(14)
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header / Track Information

    @ViewBuilder
    private var headerSection: some View {
        if playback.unifiedHasTrack {
            HStack(spacing: 12) {
                MediaImageView(
                    reference: playback.unifiedArtworkReference,
                    fixedSize: CGSize(width: 54, height: 54),
                    placeholderSystemImage: "music.note",
                    cornerRadius: 8
                )
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(playback.unifiedTitle))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(LocalizedStringKey(playback.unifiedSubtitle))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let info = playback.audioFormatInfo {
                            AudioFormatBadgeView(info: info, style: .compact)
                        } else if playback.isLiveStream {
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                    .frame(height: 36)

                Text(LocalizedStringKey("Nothing Playing"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey("Open MSRU to start listening"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 4)

                    // Active progress
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, width * effectiveProgress), height: 4)

                    // Drag thumb indicator
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, min(width * effectiveProgress - 5, width - 10)))
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let progress = min(max(value.location.x / width, 0.0), 1.0)
                            scrubbingProgress = progress
                        }
                        .onEnded { value in
                            let progress = min(max(value.location.x / width, 0.0), 1.0)
                            playback.seek(toProgress: progress)
                            scrubbingProgress = nil
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 12)

            HStack {
                let current = isScrubbing && scrubbingProgress != nil
                    ? (scrubbingProgress! * playback.duration)
                    : playback.currentTime
                Text(formatTime(current))
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatTime(playback.duration))
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Transport Controls

    private var transportSection: some View {
        HStack(spacing: 24) {
            Spacer()

            Button {
                playback.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                playback.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Button {
                playback.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Volume Controls

    private var volumeSection: some View {
        HStack(spacing: 8) {
            Button {
                playback.toggleMute()
            } label: {
                Image(systemName: playback.isMuted || playback.effectiveVolume == 0 ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { Double(playback.volume) },
                    set: { playback.setVolume(Float($0)) }
                ),
                in: 0.0...1.0
            )
            .controlSize(.mini)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
    }

    // MARK: - Footer Actions

    private var footerSection: some View {
        HStack {
            Button {
                onOpenMainWindow?()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .medium))
                    Text(LocalizedStringKey("Open MSRU"))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button {
                onQuitApp?()
            } label: {
                Text(LocalizedStringKey("Quit MSRU"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Same-File Previews

#Preview("MenuBarStatusItemLabel - Playing") {
    let controller = MSRUPreviewData.makePlaybackController()
    MenuBarStatusItemLabel(playback: controller)
        .padding()
}

#Preview("MenuBarPlayerView - Playing") {
    let controller = MSRUPreviewData.makePlaybackController()
    let _ = controller.playbackQueue.start(PlaybackItem(local: MSRUPreviewData.localTracks[0]))
    MenuBarPlayerView(
        playback: controller,
        onOpenMainWindow: {},
        onQuitApp: {}
    )
}

#Preview("MenuBarPlayerView - Empty") {
    let controller = MSRUPreviewData.makePlaybackController()
    MenuBarPlayerView(
        playback: controller,
        onOpenMainWindow: {},
        onQuitApp: {}
    )
}

#endif
