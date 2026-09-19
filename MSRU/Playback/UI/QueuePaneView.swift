//
//  QueuePaneView.swift
//  MSRU
//

import Foundation
import SwiftUI
import Observation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif


struct QueuePaneView:
    View {

    @Bindable var playback:
        PlaybackController


    var body:
        some View {

        Group {

            switch playback.activeSource {

            case .local:

                localQueue


            case .openverse:

                openverseQueue
            }
        }
    }


    // MARK: - Local Queue

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


    // MARK: - Openverse Queue

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


    // MARK: - Empty

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


    // MARK: - Local Row

    private func localRow(
        _ track:
            LocalTrack,
        isCurrent:
            Bool
    ) -> some View {

        HStack(
            spacing:
                10
        ) {

            localArtwork(
                track
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(
                    track.title
                )
                .lineLimit(
                    1
                )


                Text(
                    track.artist
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(
                    1
                )
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

            playback
                .play(
                    track,
                    queue:
                        playback.queue
                )
        }
    }


    // MARK: - Openverse Row

    private func openverseRow(
        _ track:
            OpenverseAudio,
        isCurrent:
            Bool
    ) -> some View {

        HStack(
            spacing:
                10
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
                width:
                    42,
                height:
                    42
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                        .continuous
                )
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(
                    track.title
                )
                .lineLimit(
                    2
                )


                HStack(
                    spacing:
                        5
                ) {

                    Text(
                        track.creatorTitle
                    )


                    Text(
                        "·"
                    )


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
                .lineLimit(
                    1
                )
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

            playback
                .play(
                    openverse:
                        track,
                    queue:
                        playback
                            .openverseQueue
                )
        }
    }


    // MARK: - Current Indicator

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


    // MARK: - Local Artwork

    private func localArtwork(
        _ track:
            LocalTrack
    ) -> some View {

        Group {

            if let data =
                track.artworkData {

                platformArtwork(
                    data:
                        data
                )

            } else {

                queuePlaceholder
            }
        }
        .frame(
            width:
                42,
            height:
                42
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    7,
                style:
                    .continuous
            )
        )
    }


    // MARK: - Platform Artwork Adapter

    /*
     SwiftUI owns the view API.

     AppKit / UIKit are restricted to this tiny
     platform decoding boundary.
     */

    @ViewBuilder
    private func platformArtwork(
        data:
            Data
    ) -> some View {

#if canImport(AppKit)

        if let image =
            NSImage(
                data:
                    data
            ) {

            Image(
                nsImage:
                    image
            )
            .resizable()
            .scaledToFill()

        } else {

            queuePlaceholder
        }

#elseif canImport(UIKit)

        if let image =
            UIImage(
                data:
                    data
            ) {

            Image(
                uiImage:
                    image
            )
            .resizable()
            .scaledToFill()

        } else {

            queuePlaceholder
        }

#else

        queuePlaceholder

#endif
    }


    // MARK: - Placeholder

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
        width:
            340,
        height:
            700
    )
}
