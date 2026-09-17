//
//  QueuePaneView.swift
//  MSRU
//

import SwiftUI
import Observation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif


struct QueuePaneView: View {

    @Bindable var playback:
        PlaybackController


    var body: some View {

        VStack(
            spacing: 0
        ) {

            if let currentTrack =
                playback.currentTrack {

                nowPlayingSection(
                    currentTrack
                )

                Divider()
            }


            upcomingContent
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Now Playing

    private func nowPlayingSection(
        _ track: LocalTrack
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text(
                "Now Playing"
            )
            .font(
                .caption.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .secondary
            )


            HStack(
                spacing: 10
            ) {

                artwork(
                    track,
                    size: 48
                )


                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        track.title
                    )
                    .font(
                        .callout.weight(
                            .semibold
                        )
                    )
                    .lineLimit(1)


                    Text(
                        track.artist
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }


                Spacer()


                Image(
                    systemName:
                        playback.isPlaying
                        ? "speaker.wave.2.fill"
                        : "pause.fill"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            14
        )
    }


    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingContent:
        some View {

        if playback.queue.isEmpty {

            emptyQueue

        } else if playback
                    .upNextTracks
                    .isEmpty {

            endOfQueue

        } else {

            List {

                ForEach(
                    playback
                        .upNextTracks
                ) {
                    track in

                    queueRow(
                        track
                    )
                }
            }
            .listStyle(
                .plain
            )
            .scrollContentBackground(
                .hidden
            )
        }
    }


    // MARK: - Queue Row

    private func queueRow(
        _ track: LocalTrack
    ) -> some View {

        Button {

            /*
             继续使用原始 playback.queue。

             PlaybackController 会自动找到
             track 在 Queue 中的位置，
             并把它变成 currentTrack。
             */

            playback
                .play(
                    track,
                    queue:
                        playback.queue
                )

        } label: {

            HStack(
                spacing: 10
            ) {

                artwork(
                    track,
                    size: 42
                )


                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        track.title
                    )
                    .font(
                        .callout.weight(
                            .medium
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(1)


                    Text(
                        track.artist
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }


                Spacer()


                Text(
                    durationText(
                        track.duration
                    )
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
        .padding(
            .vertical,
            3
        )
    }


    // MARK: - Empty States

    private var emptyQueue:
        some View {

        ContentUnavailableView(
            "Queue is Empty",
            systemImage:
                "music.note.list",
            description:
                Text(
                    "Play a track from your local library."
                )
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    private var endOfQueue:
        some View {

        ContentUnavailableView(
            "End of Queue",
            systemImage:
                "checkmark.circle",
            description:
                Text(
                    "There are no more tracks after the current song."
                )
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(
        _ track: LocalTrack,
        size: CGFloat
    ) -> some View {

        if let data =
                track.artworkData {

            #if os(macOS)

            if let image =
                NSImage(
                    data: data
                ) {

                Image(
                    nsImage: image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    width: size,
                    height: size
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 6,
                        style: .continuous
                    )
                )

            } else {

                artworkPlaceholder(
                    size: size
                )
            }

            #elseif os(iOS)

            if let image =
                UIImage(
                    data: data
                ) {

                Image(
                    uiImage: image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    width: size,
                    height: size
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 6,
                        style: .continuous
                    )
                )

            } else {

                artworkPlaceholder(
                    size: size
                )
            }

            #endif

        } else {

            artworkPlaceholder(
                size: size
            )
        }
    }


    private func artworkPlaceholder(
        size: CGFloat
    ) -> some View {

        RoundedRectangle(
            cornerRadius: 6,
            style: .continuous
        )
        .fill(
            .quaternary
        )
        .frame(
            width: size,
            height: size
        )
        .overlay {

            Image(
                systemName:
                    "music.note"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Duration

    private func durationText(
        _ duration:
            TimeInterval
    ) -> String {

        let totalSeconds =
            max(
                0,
                Int(
                    duration
                        .rounded()
                )
            )


        let minutes =
            totalSeconds / 60

        let seconds =
            totalSeconds % 60


        return String(
            format:
                "%d:%02d",
            minutes,
            seconds
        )
    }
}


#Preview {

    QueuePaneView(
        playback:
            PlaybackController()
    )
    .frame(
        width: 320,
        height: 700
    )
}
