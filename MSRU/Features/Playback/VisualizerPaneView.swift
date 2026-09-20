//
//  VisualizerPaneView.swift
//  MSRU
//

import SwiftUI

struct VisualizerPaneView: View {
    let playback: PlaybackController
    var onExpandCanvas: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Artwork & Track Details
                VStack(spacing: 12) {
                    if let data = playback.unifiedArtworkData,
                       let image = Image(artworkData: data) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    } else if let url = playback.unifiedArtworkURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                fallbackArtwork
                            }
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    } else {
                        fallbackArtwork
                    }

                    VStack(spacing: 4) {
                        Text(playback.unifiedTitle)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(playback.unifiedSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 16)

                // Format badge
                if let formatInfo = playback.audioFormatInfo {
                    AudioFormatBadgeView(info: formatInfo, style: .prominent)
                }

                // Waveform spectrum visualizer card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("实时频谱", systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if playback.isPlaying {
                            Text("运行中")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                    }

                    AudioVisualizerView(
                        isPlaying: playback.isPlaying,
                        volume: playback.effectiveVolume,
                        barCount: 15,
                        barWidth: 6,
                        maxHeight: 70,
                        tintColor: .accentColor
                    )
                    .frame(height: 70)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 16)

                // Audio specs table
                if let formatInfo = playback.audioFormatInfo {
                    VStack(spacing: 8) {
                        specRow(label: "编码", value: formatInfo.codec)
                        if let bitDepth = formatInfo.bitDepth {
                            specRow(label: "位深", value: bitDepth)
                        }
                        if let sampleRate = formatInfo.sampleRate {
                            specRow(label: "采样率", value: sampleRate)
                        }
                        if let bitrate = formatInfo.bitrate {
                            specRow(label: "码率", value: bitrate)
                        }
                        specRow(label: "Quality", value: formatInfo.isHiRes ? "Hi-Res Lossless" : (formatInfo.isLossless ? "Lossless" : "Standard"))
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 16)
                }

                // Expand to Full Canvas button
                if let onExpandCanvas {
                    Button(action: onExpandCanvas) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("打开沉浸式画布")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.08))
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, height: 140)
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }
}

#Preview("Visualizer Pane") {
    let playback = MSRUPreviewData.makePlaybackController()
    VisualizerPaneView(
        playback: playback,
        onExpandCanvas: {}
    )
    .frame(width: 320, height: 600)
}
