//
//  VisualizerPaneView.swift
//  MSRU
//

import SwiftUI
import MusicLibrary
import MusicPlayback

struct VisualizerPaneView: View {
    let playback: PlaybackController
    var onExpandCanvas: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Artwork & Track Details
                VStack(spacing: 12) {
                    MediaImageView(
                        reference: playback.unifiedArtworkReference,
                        fixedSize: CGSize(width: 140, height: 140),
                        thumbnailPixelSize: CGSize(width: 280, height: 280),
                        cornerRadius: 12
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    VStack(spacing: 4) {
                        Text(LocalizedStringKey(playback.unifiedTitle))
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(LocalizedStringKey(playback.unifiedSubtitle))
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Real-time Visualizer", systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if playback.isPlaying {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                                Text("Running")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                        }
                    }

                    AudioVisualizerView(
                        isPlaying: playback.isPlaying,
                        volume: playback.effectiveVolume,
                        barCount: 21,
                        barWidth: 5,
                        spacing: 4.5,
                        maxHeight: 76,
                        tintColor: .accentColor
                    )
                    .frame(height: 76)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Frequency axis labels
                    HStack {
                        Text("32 Hz")
                        Spacer()
                        Text("500 Hz")
                        Spacer()
                        Text("2 kHz")
                        Spacer()
                        Text("16 kHz")
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)

                // Audio specs table
                if let formatInfo = playback.audioFormatInfo {
                    VStack(spacing: 8) {
                        specRow(label: "Codec", value: formatInfo.codec)
                        if let bitDepth = formatInfo.bitDepth {
                            specRow(label: "Bit Depth", value: bitDepth)
                        }
                        if let sampleRate = formatInfo.sampleRate {
                            specRow(label: "Sample Rate", value: sampleRate)
                        }
                        if let bitrate = formatInfo.bitrate {
                            specRow(label: "Bitrate", value: bitrate)
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
                            Text("Open Immersive Canvas")
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

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(LocalizedStringKey(value))
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }
}

// MARK: - Audio Visualizer View

/// Dynamic multi-bar audio waveform visualizer driven by smooth continuous TimelineView.
struct AudioVisualizerView: View {
    let isPlaying: Bool
    var volume: Float = 1.0
    var barCount: Int = 19
    var barWidth: CGFloat = 4.5
    var spacing: CGFloat = 3.5
    var maxHeight: CGFloat = 28
    var minHeight: CGFloat = 4
    var tintColor: Color = .accentColor

    @ViewBuilder
    var body: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                barsView(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            barsView(time: 0.0)
        }
    }

    private func barsView(time: Double) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let height = barHeight(for: index, time: time)
                let opacity = barOpacity(for: index)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tintColor.opacity(0.7),
                                tintColor,
                                tintColor.opacity(0.95)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .opacity(opacity)
                    .frame(width: barWidth, height: height)
                    .shadow(color: tintColor.opacity(isPlaying ? 0.35 : 0.0), radius: 3, y: 0)
            }
        }
        .frame(height: maxHeight)
    }

    private func barHeight(for index: Int, time: Double) -> CGFloat {
        guard isPlaying else { return minHeight }

        let normalizedIndex = Double(index) / Double(max(1, barCount - 1))

        // Multi-frequency wave simulation:
        // Bass (low frequencies): deep rhythm bounce
        // Mids: melodic dynamics
        // Treble: rapid shimmer
        let bass = sin(time * 3.8 + normalizedIndex * 2.2) * 0.35
        let mid = cos(time * 5.6 - normalizedIndex * 4.5) * 0.3
        let treble = sin(time * 8.8 + Double(index) * 0.95) * 0.2
        let shimmer = sin(time * 13.0 - Double(index) * 1.6) * 0.15

        // Natural spectrum envelope (full bass and vibrant mids with gentle taper)
        let centerDist = abs(normalizedIndex - 0.42)
        let envelope = max(0.3, 1.0 - centerDist * 0.95)

        let composite = (bass + mid + treble + shimmer + 1.0) * 0.5 * envelope
        let dynamicScale = max(0.08, min(1.0, composite))
        let effectiveVolume = CGFloat(max(0.25, min(1.0, volume)))
        let range = maxHeight - minHeight
        let calculated = minHeight + range * CGFloat(dynamicScale) * effectiveVolume

        return max(minHeight, min(maxHeight, calculated))
    }

    private func barOpacity(for index: Int) -> Double {
        if !isPlaying {
            return 0.35
        }
        let normalized = Double(index) / Double(max(1, barCount - 1))
        return 0.75 + 0.25 * (1.0 - abs(normalized - 0.5))
    }
}

// MARK: - Ambient Backdrop View

/// Fluid ambient backdrop that creates an ethereal, blurred, dynamic atmosphere
/// tailored to the currently playing media artwork and tone.
struct AmbientBackdropView: View {
    var artworkReference: MediaImageReference? = nil
    var artworkData: Data? = nil
    var artworkURL: URL? = nil
    var primaryTint: Color = .accentColor

    @State private var driftPhase: Double = 0.0
    @State private var backdropImage: PlatformImage? = nil

    private var effectiveReference: MediaImageReference? {
        if let artworkReference {
            return artworkReference
        }
        if let artworkURL {
            return MediaImageReference(url: artworkURL)
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    if let backdropImage {
                        #if canImport(AppKit)
                        Image(nsImage: backdropImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 1.2, height: height * 1.2)
                            .blur(radius: 70)
                            .opacity(0.65)
                            .scaleEffect(1.0 + 0.05 * sin(driftPhase))
                        #elseif canImport(UIKit)
                        Image(uiImage: backdropImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 1.2, height: height * 1.2)
                            .blur(radius: 70)
                            .opacity(0.65)
                            .scaleEffect(1.0 + 0.05 * sin(driftPhase))
                        #endif
                    } else {
                        Circle()
                            .fill(primaryTint.opacity(0.55))
                            .frame(width: width * 0.75, height: width * 0.75)
                            .offset(
                                x: -width * 0.2 + 40 * cos(driftPhase),
                                y: -height * 0.15 + 30 * sin(driftPhase)
                            )
                            .blur(radius: 90)

                        Circle()
                            .fill(Color.purple.opacity(0.45))
                            .frame(width: width * 0.65, height: width * 0.65)
                            .offset(
                                x: width * 0.25 - 30 * sin(driftPhase),
                                y: height * 0.15 + 40 * cos(driftPhase)
                            )
                            .blur(radius: 80)

                        Circle()
                            .fill(Color.blue.opacity(0.35))
                            .frame(width: width * 0.5, height: width * 0.5)
                            .offset(
                                x: -width * 0.05 + 20 * sin(driftPhase * 1.5),
                                y: height * 0.2 - 20 * cos(driftPhase * 1.2)
                            )
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            }
            .ignoresSafeArea()
            .task(id: effectiveReference) {
                guard let effectiveReference else {
                    backdropImage = nil
                    return
                }
                backdropImage = await MediaImagePipeline.shared.loadThumbnail(for: effectiveReference, bucket: .px128)
            }

            Color.black.opacity(0.42)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.65)
                ],
                center: .center,
                startRadius: 200,
                endRadius: 900
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 9.0)
                .repeatForever(autoreverses: true)
            ) {
                driftPhase = .pi * 2
            }
        }
    }
}

// MARK: - Previews

#Preview("Visualizer Pane") {
    let playback = MSRUPreviewData.makePlaybackController()
    VisualizerPaneView(
        playback: playback,
        onExpandCanvas: {}
    )
    .frame(width: 320, height: 600)
}

#Preview("Audio Visualizer") {
    VStack(spacing: 24) {
        AudioVisualizerView(isPlaying: true, volume: 0.9)
        AudioVisualizerView(isPlaying: false, volume: 0.9)
    }
    .padding(40)
    .background(Color.black)
}

#Preview("Ambient Backdrop") {
    AmbientBackdropView(primaryTint: .blue)
        .frame(width: 800, height: 600)
}

