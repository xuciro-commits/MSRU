//
//  LyricsPaneView.swift
//  MSRU
//

import SwiftUI

struct LyricsPaneView: View {
    let playback: PlaybackController
    var onExpandCanvas: (() -> Void)? = nil

    // Sample/simulated verses when actual LRC is not loaded
    private var simulatedLyrics: [String] {
        if playback.isLiveStream {
            return []
        }
        return [
            "Lost in the sound of the falling rain",
            "Echoes of memories remain",
            "Whispering melodies through the trees",
            "Carried away on an autumn breeze",
            "",
            "Turn down the lights, let the music play",
            "Watching the twilight fade away",
            "Every beat and rhythm true",
            "Brings my spirit back to you",
            "",
            "Through the quiet midnight air",
            "A familiar harmony lingers there",
            "No words needed, just the song",
            "Where we both belong"
        ]
    }

    var body: some View {
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
                } else if !playback.unifiedHasTrack {
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
                } else {
                    // Lyrics lines
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(simulatedLyrics.enumerated()), id: \.offset) { index, line in
                            if line.isEmpty {
                                Spacer()
                                    .frame(height: 10)
                            } else {
                                Text(line)
                                    .font(.system(size: 16, weight: index == 2 ? .bold : .medium))
                                    .foregroundStyle(index == 2 ? Color.primary : Color.secondary.opacity(0.75))
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
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
