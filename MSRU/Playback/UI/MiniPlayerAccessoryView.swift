//
//  MiniPlayerAccessoryView.swift
//  MSRU
//

import SwiftUI
import Observation


struct MiniPlayerAccessoryView: View {

    @Bindable var playback:
        PlaybackController


    var body: some View {

        MiniPlayerBar(
            track:
                playback.currentTrack,

            isPlaying:
                playback.isPlaying,

            progress:
                playback.progress,

            canGoPrevious:
                playback.canGoPrevious,

            canGoNext:
                playback.canGoNext,

            onPrevious: {

                playback
                    .previous()
            },

            onToggle: {

                playback
                    .toggle()
            },

            onNext: {

                playback
                    .next()
            },

            onSeek: {
                progress in

                playback
                    .seek(
                        toProgress:
                            progress
                    )
            }
        )
        .padding(
            .horizontal,
            20
        )
        .padding(
            .vertical,
            8
        )
    }
}
