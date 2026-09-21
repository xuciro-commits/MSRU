//
//  LocalLibraryView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import Observation
import AppFoundationUI



struct LocalLibraryView: View {

    @Bindable var store:
        LocalLibraryStore

    @Bindable var library:
        LibraryStore

    @Bindable var playback:
        PlaybackController


    @Binding var selectedTrack:
        LocalTrack?


    let onAddMusic:
        () -> Void


    @State private var isDropTargeted =
        false

    @State private var viewMode:
        LibraryViewMode = .table

    @State private var sortField:
        LibrarySortField = .dateAdded

    @State private var sortAscending:
        Bool = false

    @State private var searchQuery:
        String = ""


    // MARK: - Body

    var body: some View {

        VStack(
            spacing: 0
        ) {

            content
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
        .task {

            await store
                .loadIfNeeded()
        }
        .dropDestination(
            for:
                URL.self
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
            targeted in

            isDropTargeted =
                targeted
        }
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        if store.tracks.isEmpty {

            emptyState

        } else {

            let tracks =
                LibraryCollectionSortFilter
                    .filterAndSort(
                        tracks:
                            store.tracks,
                        query:
                            searchQuery,
                        field:
                            sortField,
                        ascending:
                            sortAscending
                    )


            VStack(
                spacing: 0
            ) {

                LibraryFilterBar(
                    viewMode:
                        $viewMode,
                    sortField:
                        $sortField,
                    sortAscending:
                        $sortAscending,
                    searchQuery:
                        $searchQuery
                )


                Divider()


                if tracks.isEmpty {

                    ContentUnavailableView
                        .search(
                            text: searchQuery
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )

                } else {

                    switch viewMode {

                    case .table:

                        LocalTrackTableView(
                            tracks:
                                tracks,
                            selectedTrack:
                                $selectedTrack,
                            playback:
                                playback,
                            library:
                                library,
                            onDeleteTracks: { ids in
                                Task {
                                    await store.deleteTracks(withIDs: ids)
                                }
                            }
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )


                    case .grid:

                        trackGrid(
                            tracks
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
    }


    // MARK: - Empty

    private var emptyState:
        some View {

        VStack(
            spacing: 14
        ) {

            Image(
                systemName:
                    isDropTargeted
                    ? "arrow.down.circle.fill"
                    : "externaldrive"
            )
            .font(
                .system(
                    size: 42
                )
            )


            Text(
                isDropTargeted
                ? "Drop to Import"
                : "No Local Music"
            )
            .font(
                .title2.bold()
            )


            Text(
                "Import audio files, or drag files into MSRU."
            )
            .foregroundStyle(
                .secondary
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
            .buttonStyle(
                .borderedProminent
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - Grid

    private func trackGrid(
        _ tracks: [LocalTrack]
    ) -> some View {

        ScrollView {

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum:
                                160,
                            maximum:
                                200
                        ),
                        spacing:
                            18
                    )
                ],
                alignment:
                    .leading,
                spacing:
                    24
            ) {

                ForEach(
                    tracks
                ) {
                    track in

                    trackCard(
                        track
                    )
                }
            }
            .padding(28)
        }
        .hideScrollIndicatorsCompletely()
        .overlay {

            if isDropTargeted {

                RoundedRectangle(
                    cornerRadius:
                        18,
                    style:
                        .continuous
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
        _ track:
            LocalTrack
    ) -> some View {

        let isSelected =
            selectedTrack?.id == track.id

        return UnifiedTrackCardView(
            title: track.title,
            subtitle: track.artist,
            secondaryText: track.album,
            durationText: durationText(track.duration),
            qualityBadge: track.fileURL.pathExtension.uppercased(),
            isPlaying: isPlaying(track),
            isSelected: isSelected,
            onSelect: {
                selectedTrack = track
            },
            onPlay: {
                playback.toggle(track: track, queue: store.tracks)
            }
        ) {
            artwork(track)
        } actionsMenu: {
            HStack(spacing: 4) {
                if library.contains(local: track) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }

                Menu {
                    trackActions(track)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 22, height: 18)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .contextMenu {
            trackActions(track)
        }
    }


    // MARK: - Actions

    @ViewBuilder
    private func trackActions(
        _ track:
            LocalTrack
    ) -> some View {

        Button {

            playback
                .playNext(
                    track
                )

        } label: {

            Label(
                "Play Next",
                systemImage:
                    "text.line.first.and.arrowtriangle.forward"
            )
        }


        Button {

            playback
                .addToQueue(
                    track
                )

        } label: {

            Label(
                "Add to Queue",
                systemImage:
                    "text.badge.plus"
            )
        }


        Divider()


        if library.contains(
            local:
                track
        ) {

            Button {

                Task {

                    await library
                        .remove(
                            local:
                                track
                        )
                }

            } label: {

                Label(
                    "Remove from Library",
                    systemImage:
                        "minus.circle"
                )
            }

        } else {

            Button {

                Task {

                    await library
                        .add(
                            local:
                                track
                        )
                }

            } label: {

                Label(
                    "Add to Library",
                    systemImage:
                        "plus.circle"
                )
            }
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await store.deleteTracks(withIDs: [track.id])
            }
        } label: {
            Label(
                "Delete from Library",
                systemImage:
                    "trash"
            )
        }
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(_ track: LocalTrack) -> some View {
        if let data = track.artworkData, let image = Image(artworkData: data) {
            image.resizable().scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            artworkPlaceholder
        }
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
                .title
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Helpers

    private func isPlaying(
        _ track:
            LocalTrack
    ) -> Bool {

        playback
            .currentTrack?
            .id
        == track.id
        &&
        playback.isPlaying
    }


    private func durationText(
        _ duration:
            TimeInterval
    ) -> String {

        let seconds =
            max(
                0,
                Int(
                    duration
                        .rounded()
                )
            )


        return String(
            format:
                "%d:%02d",
            seconds / 60,
            seconds % 60
        )
    }
}

#Preview("Local Library") {
    @Previewable @State var selection: LocalTrack?
    let application = MSRUPreviewData.makeApplication()
    LocalLibraryView(store: application.localLibrary, library: application.library,
                     playback: application.playback, selectedTrack: $selection, onAddMusic: {})
        .frame(width: 900, height: 650)
}

#Preview("Local Library · Empty") {
    let application = MSRUPreviewData.makeApplication()
    LocalLibraryView(store: MSRUPreviewData.makeLocalLibraryStore(empty: true), library: application.library,
                     playback: application.playback, selectedTrack: .constant(nil), onAddMusic: {})
        .frame(width: 900, height: 650)
}
