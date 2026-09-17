//
//  MiniPlayerBar.swift
//  MSRU
//

import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif


struct MiniPlayerBar: View {

    let track: LocalTrack?

    let isPlaying: Bool
    let progress: Double

    let canGoPrevious: Bool
    let canGoNext: Bool

    let onPrevious: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {

        HStack(
            spacing: 14
        ) {

            artwork

            trackInfo


            Spacer(
                minLength: 20
            )


            playbackControls


            Spacer(
                minLength: 20
            )


            progressControl
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            9
        )
        .glassEffect(
            .regular,
            in:
                Capsule()
        )
    }


    // MARK: - Artwork

    @ViewBuilder
    private var artwork:
        some View {

        if let data =
                track?
                    .artworkData {

            #if os(macOS)

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
                .frame(
                    width: 42,
                    height: 42
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 7,
                        style:
                            .continuous
                    )
                )

            } else {

                artworkPlaceholder
            }

            #elseif os(iOS)

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
                .frame(
                    width: 42,
                    height: 42
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 7,
                        style:
                            .continuous
                    )
                )

            } else {

                artworkPlaceholder
            }

            #endif

        } else {

            artworkPlaceholder
        }
    }


    private var artworkPlaceholder:
        some View {

        RoundedRectangle(
            cornerRadius: 7,
            style:
                .continuous
        )
        .fill(
            .quaternary
        )
        .frame(
            width: 42,
            height: 42
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


    // MARK: - Track Info

    private var trackInfo:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                2
        ) {

            Text(
                track?
                    .title
                ?? "Nothing Playing"
            )
            .font(
                .callout.weight(
                    .semibold
                )
            )
            .lineLimit(1)


            Text(
                track?
                    .artist
                ?? "Choose a track from your library"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
        }
        .frame(
            width: 250,
            alignment:
                .leading
        )
    }


    // MARK: - Controls

    private var playbackControls:
        some View {

        HStack(
            spacing: 18
        ) {

            Button {

                onPrevious()

            } label: {

                Image(
                    systemName:
                        "backward.fill"
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !canGoPrevious
            )


            Button {

                onToggle()

            } label: {

                Image(
                    systemName:
                        isPlaying
                        ? "pause.fill"
                        : "play.fill"
                )
                .font(.headline)
                .frame(
                    width: 26,
                    height: 26
                )
            }
            .buttonStyle(.plain)
            .disabled(
                track == nil
            )


            Button {

                onNext()

            } label: {

                Image(
                    systemName:
                        "forward.fill"
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !canGoNext
            )
        }
    }


    // MARK: - Progress

    private var progressControl:
        some View {

        Slider(
            value:
                Binding(
                    get: {
                        progress
                    },
                    set: {
                        newValue in

                        onSeek(
                            newValue
                        )
                    }
                ),
            in:
                0...1
        )
        .frame(
            width: 220
        )
        .disabled(
            track == nil
        )
    }
}


#Preview {

    MiniPlayerBar(
        track: nil,
        isPlaying: false,
        progress: 0,
        canGoPrevious: false,
        canGoNext: false,
        onPrevious: {},
        onToggle: {},
        onNext: {},
        onSeek: {
            _ in
        }
    )
    .frame(
        width: 1000
    )
    .padding()
}
