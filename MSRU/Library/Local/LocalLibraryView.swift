//
//  LocalLibraryView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import Observation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif


struct LocalLibraryView: View {

    // MARK: - Dependencies

    @Bindable var store:
        LocalLibraryStore

    @Bindable var playback:
        PlaybackController

    @Binding var selectedTrack:
        LocalTrack?


    // MARK: - State

    @State private var isImporterPresented =
        false

    @State private var isDropTargeted =
        false


    // MARK: - Body

    var body: some View {

        VStack(
            spacing: 0
        ) {

            header

            Divider()

            content
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .task {

            await store
                .loadIfNeeded()
        }
        .fileImporter(
            isPresented:
                $isImporterPresented,
            allowedContentTypes: [
                .audio
            ],
            allowsMultipleSelection:
                true
        ) {
            result in

            switch result {

            case .success(
                let urls
            ):

                Task {

                    await store
                        .importFiles(
                            urls
                        )
                }


            case .failure(
                let error
            ):

                print(
                    "File importer failed:",
                    error
                )
            }
        }
        .dropDestination(
            for: URL.self
        ) {
            urls,
            _ in

            Task {

                await store
                    .importFiles(
                        urls
                    )
            }


            return true

        } isTargeted: {
            isTargeted in

            isDropTargeted =
                isTargeted
        }
    }


    // MARK: - Header

    private var header:
        some View {

        HStack {

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Local Library"
                )
                .font(
                    .largeTitle.bold()
                )


                Text(
                    "\(store.tracks.count) local tracks"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if store.isImporting {

                ProgressView()
                    .controlSize(
                        .small
                    )
            }


            Button {

                isImporterPresented =
                    true

            } label: {

                Label(
                    "Import Audio",
                    systemImage: "plus"
                )
            }
        }
        .padding(
            .horizontal,
            28
        )
        .padding(
            .vertical,
            20
        )
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        if store.tracks.isEmpty {

            emptyState

        } else {

            trackGrid
        }
    }


    // MARK: - Empty State

    private var emptyState:
        some View {

        VStack(
            spacing: 14
        ) {

            Image(
                systemName:
                    isDropTargeted
                    ? "arrow.down.circle.fill"
                    : "music.note"
            )
            .font(
                .system(
                    size: 42
                )
            )


            Text(
                isDropTargeted
                ? "Drop to Import"
                : "Drop Music Here"
            )
            .font(
                .title2.bold()
            )


            Text(
                "Drag MP3, M4A, FLAC, WAV, or other audio files into MSRU."
            )
            .foregroundStyle(
                .secondary
            )


            Button {

                isImporterPresented =
                    true

            } label: {

                Text(
                    "Choose Audio Files…"
                )
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background {

            if isDropTargeted {

                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .strokeBorder(
                    .secondary,
                    style:
                        StrokeStyle(
                            lineWidth: 2,
                            dash: [
                                8,
                                6
                            ]
                        )
                )
                .padding(20)
            }
        }
    }


    // MARK: - Track Grid

    private var trackGrid:
        some View {

        ScrollView {

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: 160,
                            maximum: 200
                        ),
                        spacing: 18
                    )
                ],
                alignment: .leading,
                spacing: 24
            ) {

                ForEach(
                    store.tracks
                ) {
                    track in

                    trackCard(
                        track
                    )
                }
            }
            .padding(28)
        }
        .overlay {

            if isDropTargeted {

                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    .ultraThinMaterial
                )
                .padding(20)
                .overlay {

                    Label(
                        "Drop to Import",
                        systemImage:
                            "arrow.down.circle.fill"
                    )
                    .font(
                        .title2.bold()
                    )
                }
            }
        }
    }


    // MARK: - Track Card

    private func trackCard(
        _ track: LocalTrack
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            ZStack(
                alignment: .bottomTrailing
            ) {

                artwork(
                    track
                )
                .aspectRatio(
                    1,
                    contentMode: .fit
                )


                playButton(
                    track
                )
                .padding(10)
            }


            Text(
                track.title
            )
            .font(
                .callout.weight(
                    .medium
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


            HStack {

                if let album =
                    track.album {

                    Text(
                        album
                    )
                    .lineLimit(1)
                }


                Spacer()


                Text(
                    durationText(
                        track.duration
                    )
                )
            }
            .font(
                .caption2
            )
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(8)
        .contentShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .background {

            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                isSelected(
                    track
                )
                ? Color.accentColor
                    .opacity(0.10)
                : Color.clear
            )
        }
        .overlay {

            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                isSelected(
                    track
                )
                ? Color.accentColor
                    .opacity(0.65)
                : Color.clear,
                lineWidth:
                    2
            )
        }
        .onTapGesture {

            selectedTrack =
                track
        }
    }


    // MARK: - Play Button

    private func playButton(
        _ track: LocalTrack
    ) -> some View {

        Button {

            /*
             播放同时选中 Card。
             */

            selectedTrack =
                track


            /*
             当前 Local Library 的排序
             同时成为 Playback Queue。

             这样上一首 / 下一首
             才知道应该播放谁。
             */

            playback
                .toggle(
                    track:
                        track,
                    queue:
                        store.tracks
                )

        } label: {

            Image(
                systemName:
                    isPlaying(
                        track
                    )
                    ? "pause.fill"
                    : "play.fill"
            )
            .font(
                .headline
            )
            .frame(
                width: 38,
                height: 38
            )
        }
        .buttonStyle(
            .glass
        )
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(
        _ track: LocalTrack
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
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )

            } else {

                artworkPlaceholder
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
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
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
            cornerRadius: 12,
            style: .continuous
        )
        .fill(
            .quaternary
        )
        .overlay {

            Image(
                systemName:
                    "music.note"
            )
            .font(
                .title
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Selection

    private func isSelected(
        _ track: LocalTrack
    ) -> Bool {

        selectedTrack?
            .id
        == track.id
    }


    // MARK: - Playback State

    private func isPlaying(
        _ track: LocalTrack
    ) -> Bool {

        playback
            .currentTrack?
            .id
        == track.id
        &&
        playback.isPlaying
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
