//
//  LyricsPaneView.swift
//  MSRU
//
//  Created for Standard Synchronized LRC Lyrics & Real-Time Sync.
//

import SwiftUI
import AppFoundation

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
                        Text(playback.unifiedTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(playback.unifiedSubtitle)
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
                                Text("完整歌词画布")
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
            Text("正在寻找歌词…")
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
            Text("未找到歌词")
                .font(.headline)
            Text("可在音频同级目录放置同名 .lrc 文件，或稍后重试。")
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
            Text("直播电台")
                .font(.headline)
            Text("连续直播音频不提供歌词。")
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
            Text("当前没有播放曲目")
                .font(.headline)
            Text("选择一首曲目以查看歌词。")
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
