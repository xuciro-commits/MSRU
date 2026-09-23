//
//  LyricsPaneView.swift
//  MSRU
//
//  Created for Standard Synchronized LRC Lyrics & Real-Time Sync.
//

import SwiftUI
import AppFoundation
import MusicDomain
import MusicPlayback

struct LyricsPaneView: View {
    let playback: PlaybackController
    var onExpandCanvas: (() -> Void)? = nil

    @State private var lyricsStore = LyricsStore.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(playback.unifiedTitle))
                            .font(.headline)
                            .lineLimit(1)
                        Text(LocalizedStringKey(playback.unifiedSubtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider()
                        .padding(.horizontal, 20)

                    if playback.isLiveStream {
                        liveStreamUnavailableView
                    } else if !playback.unifiedHasTrack {
                        noTrackView
                    } else if lyricsStore.isLoading && lyricsStore.currentDocument == nil {
                        loadingLyricsView
                    } else if let doc = lyricsStore.currentDocument, doc.isSynced {
                        tuningBar
                        syncedLyricsView(doc: doc)
                    } else if let doc = lyricsStore.currentDocument, !doc.plainText.isEmpty {
                        plainLyricsView(text: doc.plainText)
                    } else {
                        lyricsUnavailableView
                    }

                    if let onExpandCanvas {
                        Button(action: onExpandCanvas) {
                            HStack {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                Text("Full Lyrics Canvas")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onChange(of: lyricsStore.activeLineIndex) { _, newIndex in
                if let newIndex {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .task(id: playback.currentTime) {
            lyricsStore.sync(with: playback)
        }
        .task(id: playback.unifiedTitle) {
            lyricsStore.sync(with: playback)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var tuningBar: some View {
        HStack(spacing: 8) {
            Button {
                lyricsStore.adjustOffset(by: -0.5, playback: playback)
            } label: {
                Text("-0.5s")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Delay lyrics by 0.5s")

            let offset = lyricsStore.timeOffset
            let offsetText = offset == 0 ? "±0.0s" : String(format: "%+.1fs", offset)
            Text(offsetText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(offset != 0 ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    offset != 0 ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )

            Button {
                lyricsStore.adjustOffset(by: 0.5, playback: playback)
            } label: {
                Text("+0.5s")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Advance lyrics by 0.5s")

            if offset != 0 {
                Button {
                    lyricsStore.resetOffset(playback: playback)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset offset to 0.0s")
            }

            Spacer()

            if lyricsStore.isSavingTuning {
                ProgressView()
                    .controlSize(.mini)
            } else if let msg = lyricsStore.lastSaveMessage {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(LocalizedStringKey(msg))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.green)
            } else {
                Menu {
                    Button("Save to .lrc Sidecar") {
                        Task {
                            try? await lyricsStore.saveTunedLyrics(writeSidecar: true, embedInAudio: false)
                        }
                    }
                    Button("Embed in Audio File") {
                        Task {
                            try? await lyricsStore.saveTunedLyrics(writeSidecar: false, embedInAudio: true)
                        }
                    }
                    Divider()
                    Button("Save to Both (Sidecar & Embed)") {
                        Task {
                            try? await lyricsStore.saveTunedLyrics(writeSidecar: true, embedInAudio: true)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Save")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(Color.accentColor)
                }
                .menuStyle(.borderlessButton)
                .help("Write tuned lyrics permanently")
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func syncedLyricsView(doc: LrcDocument) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(doc.lines.enumerated()), id: \.offset) { index, line in
                let isActive = (index == lyricsStore.activeLineIndex)

                Button {
                    lyricsStore.seek(to: line, playback: playback)
                } label: {
                    Text(line.text.isEmpty ? "♫" : line.text)
                        .font(.system(size: isActive ? 18 : 15, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(0.65))
                        .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            isActive ? Color.accentColor.opacity(0.1) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .id(index)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func plainLyricsView(text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.secondary)
            .lineSpacing(8)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingLyricsView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Finding lyrics…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }

    private var lyricsUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.mic")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No lyrics found")
                .font(.headline)
            Text("Place a .lrc file with the same name in the audio directory, or try again later.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }

    private var liveStreamUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Live Radio")
                .font(.headline)
            Text("Lyrics are not available for live audio.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }

    private var noTrackView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.mic")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No track playing")
                .font(.headline)
            Text("Select a track to view lyrics.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
}

#Preview("Lyrics Pane") {
    let playback = MSRUPreviewData.makePlaybackController()
    LyricsPaneView(
        playback: playback,
        onExpandCanvas: {}
    )
    .frame(width: 320, height: 600)
}
