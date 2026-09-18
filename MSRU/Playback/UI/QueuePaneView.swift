//
//  QueuePaneView.swift
//  MSRU
//

import SwiftUI
import Observation

struct QueuePaneView: View {

    @Bindable var playback:
        PlaybackController

    var body: some View {

        Group {

            switch playback.activeSource {

            case .local:
                localQueue

            case .openverse:
                openverseQueue
            }
        }
    }

    @ViewBuilder
    private var localQueue:
        some View {

        if playback.currentTrack == nil {

            emptyQueue

        } else {

            List {

                Section(
                    "Now Playing"
                ) {

                    if let track =
                        playback.currentTrack {

                        localRow(
                            track,
                            isCurrent:
                                true
                        )
                    }
                }

                if !playback
                    .upNextTracks
                    .isEmpty {

                    Section(
                        "Up Next"
                    ) {

                        ForEach(
                            playback
                                .upNextTracks
                        ) {
                            track in

                            localRow(
                                track,
                                isCurrent:
                                    false
                            )
                        }
                    }
                }
            }
            .listStyle(
                .inset
            )
        }
    }

    @ViewBuilder
    private var openverseQueue:
        some View {

        if playback
            .openverseCurrentTrack
            == nil {

            emptyQueue

        } else {

            List {

                Section(
                    "Now Playing"
                ) {

                    if let track =
                        playback
                            .openverseCurrentTrack {

                        openverseRow(
                            track,
                            isCurrent:
                                true
                        )
                    }
                }

                if !playback
                    .openverseUpNextTracks
                    .isEmpty {

                    Section(
                        "Up Next"
                    ) {

                        ForEach(
                            playback
                                .openverseUpNextTracks
                        ) {
                            track in

                            openverseRow(
                                track,
                                isCurrent:
                                    false
                            )
                        }
                    }
                }
            }
            .listStyle(
                .inset
            )
        }
    }

    private var emptyQueue:
        some View {

        ContentUnavailableView(
            "Queue is Empty",
            systemImage:
                "music.note.list",
            description:
                Text(
                    "Play a track from your Library or Browse."
                )
        )
    }

    private func localRow(
        _ track:
            LocalTrack,
        isCurrent:
            Bool
    ) -> some View {

        HStack(
            spacing: 10
        ) {

            localArtwork(
                track
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(
                    track.title
                )
                .lineLimit(1)

                Text(
                    track.artist
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
            }

            Spacer()

            if isCurrent {

                currentIndicator
            }
        }
        .contentShape(
            Rectangle()
        )
        .onTapGesture {

            playback.play(
                track,
                queue:
                    playback.queue
            )
        }
    }

    private func openverseRow(
        _ track:
            OpenverseAudio,
        isCurrent:
            Bool
    ) -> some View {

        HStack(
            spacing: 10
        ) {

            AsyncImage(
                url:
                    track.thumbnailURL
            ) {
                phase in

                if case .success(
                    let image
                ) = phase {

                    image
                        .resizable()
                        .scaledToFill()

                } else {

                    queuePlaceholder
                }
            }
            .frame(
                width: 42,
                height: 42
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(
                    track.title
                )
                .lineLimit(2)

                HStack(
                    spacing: 5
                ) {

                    Text(
                        track.creatorTitle
                    )

                    Text("·")

                    Text(
                        "OPENVERSE"
                    )
                }
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
            }

            Spacer()

            if isCurrent {

                currentIndicator
            }
        }
        .contentShape(
            Rectangle()
        )
        .onTapGesture {

            playback.play(
                openverse:
                    track,
                queue:
                    playback
                        .openverseQueue
            )
        }
    }

    @ViewBuilder
    private var currentIndicator:
        some View {

        if playback.isPlaying {

            Image(
                systemName:
                    "speaker.wave.2.fill"
            )
            .foregroundStyle(
                .secondary
            )

        } else {

            Image(
                systemName:
                    "pause.fill"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func localArtwork(
        _ track:
            LocalTrack
    ) -> some View {

        Group {

            if let data =
                track.artworkData,
               let image =
                NSImage(
                    data: data
                ) {

                Image(
                    nsImage: image
                )
                .resizable()
                .scaledToFill()

            } else {

                queuePlaceholder
            }
        }
        .frame(
            width: 42,
            height: 42
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 7,
                style: .continuous
            )
        )
    }

    private var queuePlaceholder:
        some View {

        ZStack {

            Rectangle()
                .fill(
                    .quaternary
                )

            Image(
                systemName:
                    "music.note"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}

#Preview {

    QueuePaneView(
        playback:
            PlaybackController()
    )
    .frame(
        width: 340,
        height: 700
    )
}
