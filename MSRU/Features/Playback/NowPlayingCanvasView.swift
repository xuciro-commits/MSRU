//
//  NowPlayingCanvasView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation

/// Fullscreen / large modal immersive canvas for Now Playing media.
///
/// Features fluid ambient backdrop, high-resolution artwork presentation,
/// dynamic waveform visualizer, comprehensive transport controls, and
/// collapsible Up Next queue drawer.
struct NowPlayingCanvasView: View {
    @Bindable var playback: PlaybackController
    let onClose: () -> Void

    @State private var scrubbingProgress: Double? = nil
    @State private var isQueueDrawerPresented: Bool = false
    @State private var isLyricsPresented: Bool = false
    @State private var lyricsStore = LyricsStore.shared

    var body: some View {
        ZStack {
            // Ambient dynamic backdrop
            AmbientBackdropView(
                artworkReference: playback.unifiedArtworkReference,
                primaryTint: .accentColor
            )

            // Main Canvas Content
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                Spacer(minLength: 8)

                if isLyricsPresented && !playback.isLiveStream {
                    canvasLyricsView
                        .frame(maxWidth: 580)
                        .padding(.horizontal, 36)
                } else {
                    centerArtworkAndDetails
                        .padding(.horizontal, 36)
                }

                Spacer(minLength: 8)

                bottomControlsSection
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Up Next Queue Slide-in Drawer
            if isQueueDrawerPresented {
                queueDrawerOverlay
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isQueueDrawerPresented)
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button(action: onClose) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                    Text("Collapse")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Collapse to player bar (ESC)")
            .keyboardShortcut(.cancelAction)

            Spacer()

            VStack(spacing: 2) {
                Text("Now Playing")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    // MARK: - Center Content

    private var centerArtworkAndDetails: some View {
        VStack(spacing: 22) {
            artworkCard
                .frame(width: 280, height: 280)
                .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 16)

            VStack(spacing: 8) {
                Text(LocalizedStringKey(playback.unifiedTitle))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey(playback.unifiedSubtitle))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                if playback.isLiveStream {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                        Text("Live Radio")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.22), in: Capsule())
                    .foregroundStyle(.red)
                    .padding(.top, 4)
                }

                AudioVisualizerView(
                    isPlaying: playback.isPlaying,
                    volume: playback.effectiveVolume,
                    barCount: 9,
                    barWidth: 3.5,
                    maxHeight: 22,
                    tintColor: .white
                )
                .padding(.top, 4)

                if let formatInfo = playback.audioFormatInfo {
                    AudioFormatBadgeView(info: formatInfo, style: .prominent)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var artworkCard: some View {
        MediaImageView(
            reference: playback.unifiedArtworkReference,
            thumbnailPixelSize: CGSize(width: 512, height: 512),
            placeholderSystemImage: "music.note",
            cornerRadius: 18
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Bottom Controls Section

    private var bottomControlsSection: some View {
        VStack(spacing: 18) {
            scrubberRow

            HStack(spacing: 38) {
                // Previous button
                Button {
                    playback.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(playback.unifiedCanPrevious ? .white : .white.opacity(0.28))
                }
                .buttonStyle(.plain)
                .disabled(!playback.unifiedCanPrevious)
                .help("Previous")

                // Play / Pause Hero button
                Button {
                    playback.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                        if playback.isResolving {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(.black)
                        } else {
                            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.black)
                                .offset(x: playback.isPlaying ? 0 : 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!playback.unifiedHasTrack || playback.isResolving)
                .help(playback.isPlaying ? "Pause (Space)" : "Play (Space)")
                .keyboardShortcut(.space, modifiers: [])

                // Next button
                Button {
                    playback.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(playback.unifiedCanNext ? .white : .white.opacity(0.28))
                }
                .buttonStyle(.plain)
                .disabled(!playback.unifiedCanNext)
                .help("Next")
            }

            // Volume and Queue actions row
            HStack(spacing: 16) {
                // Mute button
                Button {
                    playback.toggleMute()
                } label: {
                    Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .help(playback.isMuted ? "Unmute" : "Mute")

                // Volume slider
                Slider(
                    value: Binding(
                        get: { Double(playback.volume) },
                        set: { playback.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .tint(.white)
                .frame(maxWidth: 160)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 20)

                Spacer()

                // Lyrics toggle
                if !playback.isLiveStream {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isLyricsPresented.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isLyricsPresented ? "quote.bubble.fill" : "quote.bubble")
                                .font(.system(size: 13, weight: .medium))
                            Text("Lyrics")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(isLyricsPresented ? Color.accentColor : Color.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isLyricsPresented
                                ? Color.white.opacity(0.22)
                                : Color.white.opacity(0.1),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Lyrics")
                }

                // Queue drawer toggle
                Button {
                    withAnimation {
                        isQueueDrawerPresented.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                        Text("Queue")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(isQueueDrawerPresented ? Color.accentColor : Color.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        isQueueDrawerPresented
                            ? Color.white.opacity(0.22)
                            : Color.white.opacity(0.1),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .help("Toggle Queue")
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Canvas Synchronized Lyrics

    private var canvasLyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if lyricsStore.isLoading && lyricsStore.currentDocument == nil {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Syncing lyrics…")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    } else if let doc = lyricsStore.currentDocument, doc.isSynced {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(doc.lines.enumerated()), id: \.offset) { index, line in
                                let isActive = (index == lyricsStore.activeLineIndex)
                                Button {
                                    lyricsStore.seek(to: line, playback: playback)
                                } label: {
                                    Text(line.text.isEmpty ? "♫" : line.text)
                                        .font(.system(size: isActive ? 24 : 18, weight: isActive ? .bold : .medium))
                                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.4))
                                        .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                        .blur(radius: isActive ? 0 : 0.4)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(.vertical, 24)
                    } else if let doc = lyricsStore.currentDocument, !doc.plainText.isEmpty {
                        Text(doc.plainText)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineSpacing(10)
                            .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "music.mic")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("No lyrics available")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Place a .lrc file in the same folder as the audio, and it will be loaded automatically.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    }
                }
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
    }

    // MARK: - Scrubber Row

    private var scrubberRow: some View {
        Group {
            if playback.isLiveStream {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Continuous Broadcast · Live Audio")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                }
                .frame(height: 20)
            } else {
                HStack(spacing: 10) {
                    Text(elapsedText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 44, alignment: .leading)

                    GeometryReader { geo in
                        let width = geo.size.width
                        let progress = displayedProgress

                        ZStack(alignment: .leading) {
                            // Track background
                            Capsule()
                                .fill(Color.white.opacity(0.22))
                                .frame(height: 4)

                            // Played track
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(0, width * CGFloat(progress)), height: 4)

                            // Scrubber thumb
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .shadow(radius: 2)
                                .offset(x: max(0, min(width - 12, width * CGFloat(progress) - 6)))
                        }
                        .frame(height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                                    scrubbingProgress = newProgress
                                }
                                .onEnded { value in
                                    let finalProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                                    scrubbingProgress = nil
                                    let targetTime = finalProgress * playback.duration
                                    playback.seek(to: targetTime)
                                }
                        )
                    }
                    .frame(height: 14)

                    Text(remainingText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    private var displayedProgress: Double {
        if let scrubbingProgress {
            return scrubbingProgress
        }
        guard playback.duration > 0 else { return 0 }
        return max(0, min(1, playback.currentTime / playback.duration))
    }

    private var elapsedText: String {
        let seconds: Double
        if let scrubbingProgress {
            seconds = scrubbingProgress * playback.duration
        } else {
            seconds = playback.currentTime
        }
        return formatTime(seconds)
    }

    private var remainingText: String {
        let remaining = max(0, playback.duration - playback.currentTime)
        return "-" + formatTime(remaining)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Queue Drawer Overlay

    private var queueDrawerOverlay: some View {
        HStack {
            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Up Next")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        withAnimation {
                            isQueueDrawerPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Divider()
                    .background(Color.white.opacity(0.15))

                QueuePaneView(playback: playback)
                    .scrollContentBackground(.hidden)
            }
            .frame(width: 320)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.55))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 24, x: -8, y: 0)
            .padding(16)
        }
    }
}

#Preview("Now Playing Canvas") {
    NowPlayingCanvasView(
        playback: MSRUPreviewData.makePlaybackController(),
        onClose: {}
    )
    .frame(width: 800, height: 600)
}
