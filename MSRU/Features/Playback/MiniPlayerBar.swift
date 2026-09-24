import SwiftUI
import Observation
import MusicPlayback



struct MiniPlayerBar: View {

    @Bindable var playback:
        PlaybackController

    let onToggleQueue:
        () -> Void

    var onToggleVisualizer: (() -> Void)? = nil

    var onToggleLyrics: (() -> Void)? = nil

    var onExpandNowPlaying: (() -> Void)? = nil

    @State private var scrubbingProgress: Double? = nil
    @State private var isEqualizerPresented = false


    var body: some View {

        ViewThatFits(
            in:
                .horizontal
        ) {

            standardPlayerContent

            midCompactPlayerContent

            ultraCompactPlayerContent
        }
        .frame(
            height: 60
        )
        #if os(visionOS)
        .glassBackgroundEffect(in: Capsule())
        #else
        .glassEffect(.regular, in: Capsule())
        #endif
        /*
         最后一层保险。

         无论 Artwork / AsyncImage / Scrubber
         内部将来怎么变化，都不能绘制到胶囊外面。
         */
        .clipShape(
            Capsule()
        )
    }


    // MARK: - Layouts

    private var standardPlayerContent: some View {
        ZStack {
            HStack(spacing: 0) {
                transportControls
                Spacer(minLength: 20)
                trailingUtilities(compact: false)
            }
            nowPlayingCenter
                .frame(maxWidth: 420)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var midCompactPlayerContent: some View {
        HStack(spacing: 12) {
            artwork(size: 38)

            VStack(alignment: .leading, spacing: 1) {
                metadata
                Spacer(minLength: 2)
                scrubber
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            compactTransportControls

            trailingUtilities(compact: true)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ultraCompactPlayerContent: some View {
        HStack(spacing: 8) {
            artwork(size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(playback.unifiedTitle))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(LocalizedStringKey(playback.unifiedSubtitle))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            playPauseButton(size: 15)

            queueButton
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Leading Transport

    private var previousButton: some View {
        Button {
            playback.previous()
        } label: {
            Image(systemName: "backward.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(playback.unifiedCanPrevious ? Color.primary : Color.secondary.opacity(0.35))
        .disabled(!playback.unifiedCanPrevious)
        .help("Previous")
        .fixedSize()
    }

    private func playPauseButton(size: CGFloat = 17) -> some View {
        Button {
            playback.toggle()
        } label: {
            Group {
                if playback.isResolving {
                    ProgressView()
                        .controlSize(.small)
                } else if playback.playbackErrorMessage != nil {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: size, weight: .semibold))
                } else {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: size, weight: .semibold))
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(playback.unifiedHasTrack ? Color.primary : Color.secondary.opacity(0.35))
        .disabled(!playback.unifiedHasTrack || playback.isResolving)
        .help(playback.playbackErrorMessage.map { "\($0) — Retry" }
            ?? (playback.isPlaying ? "Pause" : "Play"))
        .fixedSize()
    }

    private var nextButton: some View {
        Button {
            playback.next()
        } label: {
            Image(systemName: "forward.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(playback.unifiedCanNext ? Color.primary : Color.secondary.opacity(0.35))
        .disabled(!playback.unifiedCanNext)
        .help("Next")
        .fixedSize()
    }

    private var compactTransportControls: some View {
        HStack(alignment: .center, spacing: 14) {
            previousButton
            playPauseButton(size: 16)
            nextButton
        }
        .fixedSize()
    }

    private var transportControls: some View {
        HStack(alignment: .center, spacing: 22) {
            previousButton
            playPauseButton(size: 17)
            nextButton
        }
        .fixedSize()
    }

    // MARK: - Center Now Playing

    private var nowPlayingCenter: some View {
        HStack(alignment: .center, spacing: 11) {
            artwork(size: 42)

            VStack(alignment: .leading, spacing: 0) {
                metadata
                Spacer(minLength: 2)
                scrubber
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 44)
        .clipped()
    }

    private var scrubber: some View {
        HStack(spacing: 6) {
            HoverScrubber(
                progress: playbackProgress,
                isEnabled: playback.unifiedHasTrack && playback.duration > 0,
                onScrubbingChanged: { preview in
                    scrubbingProgress = preview
                },
                onSeek: { progress in
                    playback.seek(toProgress: progress)
                }
            )

            if playback.duration > 0 {
                Text(timeDisplayString)
                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if playback.radioCurrentStation != nil {
                Text("Live")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(height: 10)
    }

    private var timeDisplayString: String {
        let currentSeconds: TimeInterval
        if let preview = scrubbingProgress {
            currentSeconds = preview * playback.duration
        } else {
            currentSeconds = playback.currentTime
        }
        return "\(formatTime(currentSeconds)) / \(formatTime(playback.duration))"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }


    private var metadata:
        some View {

        VStack(
            alignment: .leading,
            spacing: 1
        ) {

            HStack(spacing: 6) {
                Text(
                    LocalizedStringKey(playback.unifiedTitle)
                )
                .font(
                    .system(
                        size: 13,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .primary
                )
                .lineLimit(1)
                .truncationMode(
                    .tail
                )

                if let info = playback.audioFormatInfo {
                    AudioFormatBadgeView(info: info, style: .compact)
                }
            }


            Text(
                LocalizedStringKey(playback.unifiedSubtitle)
            )
            .font(
                .system(
                    size: 10
                )
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
            .truncationMode(
                .tail
            )
        }
    }


    // MARK: - Artwork

    private func artwork(size: CGFloat = 42) -> some View {
        Button {
            onExpandNowPlaying?()
        } label: {
            artworkImage(size: size)
        }
        .buttonStyle(.plain)
        .help("Open Now Playing Canvas")
    }

    private func artworkImage(size: CGFloat = 42) -> some View {
        MediaImageView(
            reference: playback.unifiedArtworkReference,
            fixedSize: CGSize(width: size, height: size),
            placeholderSystemImage: "music.note",
            cornerRadius: size > 36 ? 7 : 6
        )
        .id(playback.unifiedArtworkReference)
    }

    private func artworkPlaceholder(size: CGFloat = 42) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: size > 36 ? 7 : 6,
                style: .continuous
            )
            .fill(Color.primary.opacity(0.08))

            Image(systemName: "music.note")
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Trailing

    private var lyricsButton: some View {
        Button {
            onToggleLyrics?()
        } label: {
            Image(systemName: "quote.bubble")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.secondary)
        .help("Lyrics")
        .fixedSize()
    }

    private var visualizerButton: some View {
        Button {
            onToggleVisualizer?()
        } label: {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.secondary)
        .help("Visualizer")
        .fixedSize()
    }

    private var queueButton: some View {
        Button(action: onToggleQueue) {
            Image(systemName: "list.bullet")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary)
        .help("Up Next")
        .fixedSize()
    }

    private var expandButton: some View {
        Button {
            onExpandNowPlaying?()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.secondary)
        .help("Full Canvas")
        .fixedSize()
    }

    @ViewBuilder
    private func trailingUtilities(
        compact: Bool
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 10
        ) {
            if !compact {
                volumeControl
                equalizerButton
                #if os(macOS)
                AudioOutputMenu(playback: playback)
                #endif
                if playback.unifiedHasTrack {
                    providerBadge
                }
            }

            if onToggleLyrics != nil {
                lyricsButton
            }

            if onToggleVisualizer != nil {
                visualizerButton
            }

            queueButton

            if onExpandNowPlaying != nil {
                expandButton
            }
        }
        .fixedSize()
    }

    private var volumeControl: some View {
        HStack(spacing: 6) {
            Button(action: {
                playback.toggleMute()
            }) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(playback.isMuted ? "Unmute" : "Mute")

            Slider(
                value: Binding(
                    get: { Double(playback.volume) },
                    set: { playback.setVolume(Float($0)) }
                ),
                in: 0.0...1.0
            )
            .frame(width: 72)
            .controlSize(.mini)
        }
    }

    private var equalizerButton: some View {
        Button {
            isEqualizerPresented.toggle()
        } label: {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 13))
                .foregroundStyle(playback.equalizer.state.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .help("Equalizer")
        .popover(isPresented: $isEqualizerPresented) {
            EqualizerPanel(playback: playback)
        }
    }

    private var volumeIconName: String {
        if playback.isMuted || playback.volume == 0 {
            return "speaker.slash.fill"
        } else if playback.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if playback.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }


    private var providerBadge:
        some View {

        Text(
            playback.unifiedProviderLabel
        )
        .font(
            .system(
                size: 8,
                weight: .semibold
            )
        )
        .foregroundStyle(
            .secondary
        )
        .lineLimit(1)
        .padding(
            .horizontal,
            7
        )
        .padding(
            .vertical,
            4
        )
        .background(
            Color.primary
                .opacity(0.07),
            in:
                Capsule()
        )
    }


    // MARK: - Playback Progress

    private var playbackProgress:
        Double {

        guard playback.duration > 0,
              playback.currentTime.isFinite,
              playback.duration.isFinite
        else {

            return 0
        }


        return min(
            max(
                playback.currentTime
                / playback.duration,
                0
            ),
            1
        )
    }
}


// MARK: - Hover Scrubber

private struct HoverScrubber:
    View {

    let progress:
        Double

    let isEnabled:
        Bool

    let onSeek:
        (Double) -> Void

    var onScrubbingChanged:
        ((Double?) -> Void)? = nil

    init(
        progress: Double,
        isEnabled: Bool,
        onScrubbingChanged: ((Double?) -> Void)? = nil,
        onSeek: @escaping (Double) -> Void
    ) {
        self.progress = progress
        self.isEnabled = isEnabled
        self.onScrubbingChanged = onScrubbingChanged
        self.onSeek = onSeek
    }


    @State private var isHovering =
        false

    @State private var isDragging =
        false

    @State private var dragProgress:
        Double?


    private var displayedProgress:
        Double {

        dragProgress
        ?? min(
            max(
                progress,
                0
            ),
            1
        )
    }


    private var showsThumb:
        Bool {

        isHovering
        || isDragging
    }


    var body: some View {

        GeometryReader {
            geometry in

            let width =
                max(
                    geometry.size.width,
                    1
                )

            let value =
                displayedProgress

            let thumbSize:
                CGFloat = 9

            let thumbX =
                (
                    width
                    - thumbSize
                )
                * value


            ZStack(
                alignment: .leading
            ) {

                /*
                 Visual track:
                 很细。

                 Hit area 由外层 16pt 高度负责，
                 所以不需要用户精确瞄准一条线。
                 */
                Capsule()
                    .fill(
                        Color.primary
                            .opacity(
                                0.16
                            )
                    )
                    .frame(
                        height: 2
                    )


                Capsule()
                    .fill(
                        Color.primary
                            .opacity(
                                showsThumb
                                ? 0.72
                                : 0.42
                            )
                    )
                    .frame(
                        width:
                            width
                            * value,
                        height: 2
                    )


                Circle()
                    .fill(
                        Color.primary
                    )
                    .frame(
                        width:
                            thumbSize,
                        height:
                            thumbSize
                    )
                    .offset(
                        x:
                            thumbX
                    )
                    .opacity(
                        showsThumb
                        && isEnabled
                        ? 1
                        : 0
                    )
                    .scaleEffect(
                        isDragging
                        ? 1.12
                        : 1
                    )
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity,
                alignment:
                    .center
            )
            .contentShape(
                Rectangle()
            )
            .gesture(
                DragGesture(
                    minimumDistance: 0
                )
                .onChanged {
                    value in

                    guard isEnabled
                    else {
                        return
                    }

                    isDragging =
                        true

                    let progress =
                        normalizedProgress(
                            x:
                                value.location.x,
                            width:
                                width
                        )

                    dragProgress =
                        progress

                    onScrubbingChanged?(
                        progress
                    )
                }
                .onEnded {
                    value in

                    guard isEnabled
                    else {
                        isDragging =
                            false

                        dragProgress =
                            nil

                        onScrubbingChanged?(
                            nil
                        )

                        return
                    }

                    let progress =
                        normalizedProgress(
                            x:
                                value.location.x,
                            width:
                                width
                        )

                    onSeek(
                        progress
                    )

                    isDragging =
                        false

                    dragProgress =
                        nil

                    onScrubbingChanged?(
                        nil
                    )
                }
            )
        }
        .frame(
            height: 16
        )

        #if os(macOS)

        .onHover {
            hovering in

            withAnimation(
                .easeOut(
                    duration: 0.12
                )
            ) {

                isHovering =
                    hovering
            }
        }

        #endif

        .opacity(
            isEnabled
            ? 1
            : 0.45
        )
        .animation(
            .easeOut(
                duration: 0.12
            ),
            value:
                showsThumb
        )
    }


    private func normalizedProgress(
        x: CGFloat,
        width: CGFloat
    ) -> Double {

        guard width > 0
        else {

            return 0
        }


        return min(
            max(
                Double(
                    x / width
                ),
                0
            ),
            1
        )
    }
}


// MARK: - Preview

#Preview {

    MiniPlayerBar(
        playback:
            MSRUPreviewData.makePlaybackController(),
        onToggleQueue: {}
    )
    .frame(
        width: 900
    )
    .padding(
        30
    )
}

#Preview("Hover Scrubber") {
    HoverScrubber(progress: 0.4, isEnabled: true, onSeek: { _ in })
        .frame(width: 360, height: 32)
        .padding()
}

#Preview("Mini Player · Compact") {
    let playback = MSRUPreviewData.makePlaybackController()
    let _ = playback.playbackQueue.start(PlaybackItem(local: MSRUPreviewData.localTracks[0]))
    MiniPlayerBar(playback: playback, onToggleQueue: {})
        .frame(width: 320).padding()
}

#Preview("Mini Player · Mid-Compact") {
    let playback = MSRUPreviewData.makePlaybackController()
    let _ = playback.playbackQueue.start(PlaybackItem(local: MSRUPreviewData.localTracks[0]))
    MiniPlayerBar(playback: playback, onToggleQueue: {})
        .frame(width: 480).padding()
}

// MARK: - Mini Player Accessory View

struct MiniPlayerAccessoryView: View {

    @Bindable var playback: PlaybackController
    let onToggleQueue: () -> Void
    var onToggleVisualizer: (() -> Void)? = nil
    var onToggleLyrics: (() -> Void)? = nil
    var onExpandNowPlaying: (() -> Void)? = nil

    var body: some View {
        MiniPlayerBar(
            playback: playback,
            onToggleQueue: onToggleQueue,
            onToggleVisualizer: onToggleVisualizer,
            onToggleLyrics: onToggleLyrics,
            onExpandNowPlaying: onExpandNowPlaying
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview("Mini Player Accessory") {
    MiniPlayerAccessoryView(
        playback: MSRUPreviewData.makePlaybackController(),
        onToggleQueue: {}
    )
    .frame(width: 480)
}
