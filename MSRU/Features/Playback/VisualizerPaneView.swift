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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Real-time Visualizer", systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if playback.isPlaying {
                            Text("Running")
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

/// Dynamic multi-bar audio waveform visualizer.
struct AudioVisualizerView: View {
    let isPlaying: Bool
    var volume: Float = 1.0
    var barCount: Int = 7
    var barWidth: CGFloat = 3.5
    var spacing: CGFloat = 3
    var maxHeight: CGFloat = 28
    var minHeight: CGFloat = 4
    var tintColor: Color = .accentColor

    @State private var phase: Double = 0.0

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(tintColor.opacity(barOpacity(for: index)))
                    .frame(
                        width: barWidth,
                        height: barHeight(for: index)
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimation()
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    phase = 0.0
                }
            }
        }
    }

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.65)
            .repeatForever(autoreverses: true)
        ) {
            phase = 1.0
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isPlaying else { return minHeight }

        let normalizedIndex = Double(index) / Double(max(1, barCount - 1))
        let centerWeight = 1.0 - abs(normalizedIndex - 0.5) * 1.2
        let harmonicFactor = sin((Double(index) * 0.9) + (phase * .pi))

        let dynamicScale = (centerWeight * 0.55 + 0.45) * (0.35 + 0.65 * abs(harmonicFactor))
        let effectiveVolume = CGFloat(max(0.15, min(1.0, volume)))
        let targetHeight = minHeight + (maxHeight - minHeight) * CGFloat(dynamicScale) * effectiveVolume

        return max(minHeight, min(maxHeight, targetHeight))
    }

    private func barOpacity(for index: Int) -> Double {
        if !isPlaying {
            return 0.4
        }
        let normalized = Double(index) / Double(max(1, barCount - 1))
        return 0.65 + 0.35 * (1.0 - abs(normalized - 0.5))
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

