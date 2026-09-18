//
//  LibraryView.swift
//  MSRU
//

import SwiftUI
import Observation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif


struct LibraryView: View {

    enum Scope:
        String,
        CaseIterable,
        Identifiable {

        case saved
        case local


        var id:
            Self {

            self
        }


        var title:
            String {

            switch self {

            case .saved:
                return "Library"

            case .local:
                return "Local Files"
            }
        }
    }


    @Bindable var library:
        LibraryStore

    @Bindable var localStore:
        LocalLibraryStore

    @Bindable var playback:
        PlaybackController


    @Binding var selectedLocalTrack:
        LocalTrack?


    let onAddMusic:
        () -> Void


    @State private var scope:
        Scope = .saved


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
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - Header

    private var header:
        some View {

        HStack(
            alignment:
                .center,
            spacing:
                20
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                Text(
                    "Library"
                )
                .font(
                    .largeTitle.bold()
                )


                Text(
                    librarySubtitle
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Picker(
                "Library View",
                selection:
                    $scope
            ) {

                ForEach(
                    Scope.allCases
                ) {
                    scope in

                    Text(
                        scope.title
                    )
                    .tag(
                        scope
                    )
                }
            }
            .pickerStyle(
                .segmented
            )
            .frame(
                width: 220
            )


            Button {

                onAddMusic()

            } label: {

                Label(
                    "Add Music",
                    systemImage:
                        "plus"
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


    private var librarySubtitle:
        String {

        switch scope {

        case .saved:

            return
                "\(library.tracks.count) saved tracks"

        case .local:

            return
                "\(localStore.tracks.count) local tracks"
        }
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        switch scope {

        case .saved:

            savedLibrary


        case .local:

            LocalLibraryView(
                store:
                    localStore,
                library:
                    library,
                playback:
                    playback,
                selectedTrack:
                    $selectedLocalTrack,
                onAddMusic:
                    onAddMusic
            )
        }
    }


    // MARK: - Saved Library

    @ViewBuilder
    private var savedLibrary:
        some View {

        if library.isLoading {

            VStack(
                spacing: 12
            ) {

                ProgressView()

                Text(
                    "Loading Library…"
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )

        } else if library.tracks.isEmpty {

            ContentUnavailableView {

                Label(
                    "Your Library is Empty",
                    systemImage:
                        "music.note.house"
                )

            } description: {

                Text(
                    "Add tracks from Browse or Local Files."
                )

            } actions: {

                Button(
                    "Add Music"
                ) {

                    onAddMusic()
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )

        } else {

            savedGrid
        }
    }


    // MARK: - Saved Grid

    private var savedGrid:
        some View {

        ScrollView {

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum:
                                170,
                            maximum:
                                220
                        ),
                        spacing:
                            20
                    )
                ],
                alignment:
                    .leading,
                spacing:
                    26
            ) {

                ForEach(
                    library.tracks
                ) {
                    track in

                    savedCard(
                        track
                    )
                }
            }
            .padding(28)
        }
    }


    // MARK: - Card

    private func savedCard(
        _ track:
            LibraryTrack
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                9
        ) {

            artwork(
                track
            )
            .aspectRatio(
                1,
                contentMode:
                    .fit
            )


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


            HStack(
                spacing: 6
            ) {

                sourceLabels(
                    track
                )


                Spacer()


                Menu {

                    Button(
                        role:
                            .destructive
                    ) {

                        Task {

                            await library
                                .remove(
                                    id:
                                        track.id
                                )
                        }

                    } label: {

                        Label(
                            "Remove from Library",
                            systemImage:
                                "trash"
                        )
                    }

                } label: {

                    Image(
                        systemName:
                            "ellipsis"
                    )
                    .frame(
                        width: 24,
                        height: 20
                    )
                }
                .menuStyle(
                    .borderlessButton
                )
                .fixedSize()
            }
        }
        .contextMenu {

            Button(
                role:
                    .destructive
            ) {

                Task {

                    await library
                        .remove(
                            id:
                                track.id
                        )
                }

            } label: {

                Label(
                    "Remove from Library",
                    systemImage:
                        "trash"
                )
            }
        }
    }


    // MARK: - Source

    @ViewBuilder
    private func sourceLabels(
        _ track:
            LibraryTrack
    ) -> some View {

        let kinds =
            Array(
                Set(
                    track.sources
                        .map(
                            \.kind
                        )
                )
            )
            .sorted {
                $0.rawValue
                    < $1.rawValue
            }


        HStack(
            spacing: 4
        ) {

            ForEach(
                kinds,
                id:
                    \.self
            ) {
                kind in

                Text(
                    sourceTitle(
                        kind
                    )
                )
                .font(
                    .caption2.weight(
                        .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .padding(
                    .horizontal,
                    7
                )
                .padding(
                    .vertical,
                    3
                )
                .background(
                    .quaternary,
                    in:
                        Capsule()
                )
            }
        }
    }


    private func sourceTitle(
        _ kind:
            LibraryPlaybackSourceKind
    ) -> String {

        switch kind {

        case .local:
            return "LOCAL"

        case .openverse:
            return "OPENVERSE"

        case .jamendo:
            return "JAMENDO"

        case .appleMusic:
            return "APPLE"

        case .openSubsonic:
            return "SUBSONIC"
        }
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(
        _ track:
            LibraryTrack
    ) -> some View {

        if let data =
                track.artworkData {

            localArtwork(
                data
            )

        } else if let url =
                    track.artworkURL {

            AsyncImage(
                url:
                    url
            ) {
                phase in

                switch phase {

                case .success(
                    let image
                ):

                    image
                        .resizable()
                        .scaledToFill()


                default:

                    artworkPlaceholder
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
            )

        } else {

            artworkPlaceholder
        }
    }


    @ViewBuilder
    private func localArtwork(
        _ data:
            Data
    ) -> some View {

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
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        12,
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
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
            )

        } else {

            artworkPlaceholder
        }

        #endif
    }


    private var artworkPlaceholder:
        some View {

        RoundedRectangle(
            cornerRadius:
                12,
            style:
                .continuous
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
                .title2
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}
