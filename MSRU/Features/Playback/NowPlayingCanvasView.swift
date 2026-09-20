//
//  NowPlayingCanvasView.swift
//  MSRU
//

import SwiftUI
import Observation

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

    var body: some View {
        ZStack {
            // Ambient dynamic backdrop
            AmbientBackdropView(
                artworkData: playback.unifiedArtworkData,
                artworkURL: playback.unifiedArtworkURL
            )

            // Main Canvas Content
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                Spacer(minLength: 8)

                centerArtworkAndDetails
                    .padding(.horizontal, 36)

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
                    Text("收起")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("收起到播放器栏（ESC）")
            .keyboardShortcut(.cancelAction)

            Spacer()

            VStack(spacing: 2) {
                Text("正在播放")
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
            .help("关闭")
        }
    }

    // MARK: - Center Content

    private var centerArtworkAndDetails: some View {
        VStack(spacing: 22) {
            artworkCard
                .frame(width: 280, height: 280)
                .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 16)

            VStack(spacing: 8) {
                Text(playback.unifiedTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(playback.unifiedSubtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                if playback.isLiveStream {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                        Text("直播电台")
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
        Group {
            if let data = playback.unifiedArtworkData,
               let image = Image(artworkData: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else if let url = playback.unifiedArtworkURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))

            Image(systemName: "music.note")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
        }
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
                .help("上一首")

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
                .help(playback.isPlaying ? "暂停（空格）" : "播放（空格）")
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
                .help("下一首")
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
                .help(playback.isMuted ? "取消静音" : "静音")

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

                // Queue drawer toggle
                Button {
                    withAnimation {
                        isQueueDrawerPresented.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                        Text("队列")
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
                .help("切换队列")
            }
            .padding(.top, 6)
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
                        Text("连续广播 · 直播音频")
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
                    Text("接下来播放")
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
