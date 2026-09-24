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

    @AppStorage("msru.visualizer.style") private var selectedStyle: VisualizerStyle = .liquidWave
    @AppStorage("msru.visualizer.theme") private var selectedTheme: VisualizerColorTheme = .aurora
    @State private var sensitivity: Double = 1.0

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

                // Interactive Multi-Style Visualizer Card
                visualizerSection

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

    private var visualizerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Style Picker Menu & Running indicator
            HStack {
                Menu {
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(VisualizerStyle.allCases) { style in
                            Label(style.title, systemImage: style.icon)
                                .tag(style)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: selectedStyle.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(selectedStyle.title)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Theme color dots
                HStack(spacing: 6) {
                    ForEach(VisualizerColorTheme.allCases) { theme in
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: selectedTheme == theme ? 13 : 9, height: selectedTheme == theme ? 13 : 9)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: selectedTheme == theme ? 1.5 : 0)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTheme = theme
                                }
                            }
                            .help(theme.title)
                    }
                }
            }

            // Visualizer Canvas Frame
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )

                UnifiedVisualizerView(
                    style: selectedStyle,
                    theme: selectedTheme,
                    isPlaying: playback.isPlaying,
                    volume: playback.effectiveVolume,
                    sensitivity: sensitivity
                )
                .frame(height: 140)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .frame(height: 156)

            // Frequency axis labels
            HStack {
                Text("32 Hz")
                Spacer()
                Text("250 Hz")
                Spacer()
                Text("1 kHz")
                Spacer()
                Text("4 kHz")
                Spacer()
                Text("16 kHz")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)

            // Sensitivity slider
            HStack(spacing: 8) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Slider(value: $sensitivity, in: 0.5...1.8)
                    .controlSize(.mini)
                    .tint(selectedTheme.primaryColor)

                Text(String(format: "%.1fx", sensitivity))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.top, 2)
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
        TimelineView(.animation(minimumInterval: isPlaying ? 1.0 / 60.0 : 1.0 / 30.0)) { timeline in
            barsView(time: timeline.date.timeIntervalSinceReferenceDate)
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
        let energy = VisualizerEngine.computeBand(
            index: index,
            totalBands: barCount,
            time: time,
            isPlaying: isPlaying,
            volume: volume,
            sensitivity: 1.0
        )
        let range = maxHeight - minHeight
        return minHeight + range * CGFloat(energy)
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

