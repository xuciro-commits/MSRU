import SwiftUI
import Observation



struct MiniPlayerBar: View {

    @Bindable var playback:
        PlaybackController

    let onToggleQueue:
        () -> Void


    var body: some View {

        GeometryReader {
            proxy in

            playerContent(
                width:
                    proxy.size.width
            )
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


    // MARK: - Layout

    @ViewBuilder
    private func playerContent(width: CGFloat) -> some View {
        if width < 600 {
            HStack(spacing: 10) {
                nowPlayingCenter
                transportControls
                trailingUtilities(compact: true)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack {
                HStack(spacing: 0) {
                    transportControls
                    Spacer(minLength: 20)
                    trailingUtilities(compact: width < 720)
                }
                nowPlayingCenter.frame(width: min(420, width * 0.44))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Leading Transport

    private var transportControls:
        some View {

        HStack(
            alignment: .center,
            spacing: 22
        ) {

            Button {

                playback.previous()

            } label: {

                Image(
                    systemName:
                        "backward.fill"
                )
                .frame(
                    width: 18,
                    height: 24
                )
            }
            .disabled(
                !playback.unifiedCanPrevious
            )
            .help(
                "Previous"
            )


            Button {

                playback.toggle()

            } label: {

                Group {

                    if playback.isResolving {

                        ProgressView()
                            .controlSize(
                                .small
                            )

                    } else {

                        Image(
                            systemName:
                                playback.isPlaying
                                ? "pause.fill"
                                : "play.fill"
                        )
                    }
                }
                .frame(
                    width: 22,
                    height: 28
                )
            }
            .disabled(
                !playback.unifiedHasTrack
                || playback.isResolving
            )
            .help(
                playback.isPlaying
                ? "Pause"
                : "Play"
            )


            Button {

                playback.next()

            } label: {

                Image(
                    systemName:
                        "forward.fill"
                )
                .frame(
                    width: 18,
                    height: 24
                )
            }
            .disabled(
                !playback.unifiedCanNext
            )
            .help(
                "Next"
            )
        }
        .buttonStyle(
            .plain
        )
        .font(
            .system(
                size: 17,
                weight: .semibold
            )
        )
        .foregroundStyle(
            .primary
        )
        .fixedSize()
    }


    // MARK: - Center Now Playing

    private var nowPlayingCenter:
        some View {

        HStack(
            alignment: .center,
            spacing: 11
        ) {

            artwork


            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                metadata


                Spacer(
                    minLength: 2
                )


                HoverScrubber(
                    progress:
                        playbackProgress,
                    isEnabled:
                        playback.unifiedHasTrack
                        && playback.duration > 0,
                    onSeek: {
                        progress in

                        playback.seek(
                            toProgress:
                                progress
                        )
                    }
                )
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
        }
        .frame(
            height: 44
        )
        .clipped()
    }


    private var metadata:
        some View {

        VStack(
            alignment: .leading,
            spacing: 1
        ) {

            Text(
                playback.unifiedTitle
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


            Text(
                playback.unifiedSubtitle
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

    private var artwork:
        some View {

        Group {

            if let data = playback.unifiedArtworkData,
               let image = Image(artworkData: data) {
                image.resizable().scaledToFill()
            } else if let url = playback.unifiedArtworkURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        /*
         先约束尺寸，再裁剪内容。

         之前的溢出问题不能再出现。
         */
        .frame(
            width: 42,
            height: 42
        )
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 7,
                style: .continuous
            )
        )
        .fixedSize()
    }


    private var artworkPlaceholder:
        some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: 7,
                style: .continuous
            )
            .fill(
                Color.primary
                    .opacity(0.08)
            )


            Image(
                systemName:
                    "music.note"
            )
            .font(
                .system(
                    size: 15,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Trailing

    @ViewBuilder
    private func trailingUtilities(
        compact: Bool
    ) -> some View {

        HStack(
            alignment: .center,
            spacing: 14
        ) {

            if !compact,
               playback.unifiedHasTrack {

                providerBadge
            }


            Button(
                action:
                    onToggleQueue
            ) {

                Image(
                    systemName:
                        "list.bullet"
                )
                .font(
                    .system(
                        size: 16,
                        weight: .medium
                    )
                )
                .frame(
                    width: 24,
                    height: 28
                )
            }
            .buttonStyle(
                .plain
            )
            .help(
                "Up Next"
            )
        }
        .fixedSize()
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


                    onSeek(
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
