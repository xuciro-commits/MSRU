//
//  LibraryView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation


struct LibraryView:
    View {

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

                return
                    "Library"


            case .local:

                return
                    "Local Files"
            }
        }
    }


    // MARK: - Feature

    let feature:
        FeatureHost<LibraryFeature>


    // MARK: - Shared Dependencies

    @Bindable
    var localStore:
        LocalLibraryStore


    @Bindable
    var playback:
        PlaybackController


    // MARK: - Scene State

    @Binding
    var selectedLocalTrack:
        LocalTrack?

    @Binding
    var selectedLibraryTrack:
        LibraryTrack?


    let onAddMusic:
        () -> Void


    // MARK: - Local UI State

    @State
    private var scope:
        Scope = .saved

    @State
    private var viewMode:
        LibraryViewMode = .table

    @State
    private var sortField:
        LibrarySortField = .dateAdded

    @State
    private var sortAscending:
        Bool = false

    @State
    private var searchQuery:
        String = ""


    // MARK: - Init

    init(
        feature:
            FeatureHost<LibraryFeature>,
        localStore:
            LocalLibraryStore,
        playback:
            PlaybackController,
        selectedLocalTrack:
            Binding<LocalTrack?>,
        selectedLibraryTrack:
            Binding<LibraryTrack?> = .constant(nil),
        onAddMusic:
            @escaping () -> Void
    ) {
        self.feature = feature
        self.localStore = localStore
        self.playback = playback
        self._selectedLocalTrack = selectedLocalTrack
        self._selectedLibraryTrack = selectedLibraryTrack
        self.onAddMusic = onAddMusic
    }


    // MARK: - Body

    var body:
        some View {

        VStack(
            spacing:
                0
        ) {

            header


            Divider()
            if let error = feature.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                    Button("Reload Library") { Task { await feature.libraryStore.load() } }
                }.font(.callout).padding()
            }
            if let error = playback.playbackErrorMessage {
                Label(error, systemImage: "speaker.slash").font(.callout).padding()
            }
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

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                libraryTitle
                Spacer()
                scopePicker.frame(width: 220)
                importButton
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    libraryTitle
                    Spacer()
                    importButton
                }
                scopePicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var libraryTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Library").font(.largeTitle.bold())
            Text(librarySubtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    private var scopePicker: some View {
        Picker("Library View", selection: $scope) {
            ForEach(Scope.allCases) { scope in Text(scope.title).tag(scope) }
        }
        .pickerStyle(.segmented)
    }

    private var importButton: some View {
        Button(action: onAddMusic) { Label("Add Music", systemImage: "plus") }
    }

    private var librarySubtitle:
        String {

        switch scope {

        case .saved:

            return
                "\(feature.tracks.count) saved tracks"


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
                    feature
                        .libraryStore,
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

        if feature.isLoading {

            VStack(
                spacing:
                    12
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


        } else if
            feature
                .tracks
                .isEmpty {

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

            let tracks =
                LibraryCollectionSortFilter
                    .filterAndSort(
                        tracks:
                            feature.tracks,
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

                        LibraryTrackTableView(
                            tracks:
                                tracks,
                            selectedTrack:
                                $selectedLibraryTrack,
                            playback:
                                playback,
                            library:
                                feature.libraryStore
                        )


                    case .grid:

                        savedGrid(
                            tracks
                        )
                    }
                }
            }
        }
    }


    // MARK: - Saved Grid

    private func savedGrid(
        _ tracks: [LibraryTrack]
    ) -> some View {

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
                    tracks
                ) {
                    track in

                    savedCard(
                        track
                    )
                }
            }
            .padding(
                28
            )
        }
    }


    // MARK: - Card

    private func savedCard(
        _ track:
            LibraryTrack
    ) -> some View {

        let isRemoving =
            feature
                .isRemoving(
                    track
                )

        let isSelected =
            selectedLibraryTrack?.id == track.id


        return VStack(
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
            .overlay(alignment: .bottomTrailing) {
                let item = PlaybackItem(library: track)
                Button {
                    feature.send(.playRequested(id: track.id))
                } label: {
                    Image(systemName: playback.currentItem?.id == item?.id && playback.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(item == nil)
                .help(item == nil ? "No supported playback source" : "Play or pause")
                .accessibilityLabel("Play or pause " + track.title)
                .padding(8)
            }


            Text(
                track.title
            )
            .font(
                .callout
                    .weight(
                        .semibold
                    )
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


            HStack(
                spacing:
                    6
            ) {

                sourceLabels(
                    track
                )


                Spacer()


                if isRemoving {

                    ProgressView()
                        .controlSize(
                            .small
                        )

                } else {

                    Menu {
                        playbackActions(track)
                        removeButton(
                            track
                        )

                    } label: {

                        Image(
                            systemName:
                                "ellipsis"
                        )
                        .frame(
                            width:
                                24,
                            height:
                                20
                        )
                    }
                    .menuStyle(
                        .borderlessButton
                    )
                    .fixedSize()
                }
            }
        }
        .contextMenu {
            playbackActions(track)
            if !isRemoving {

                removeButton(
                    track
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedLibraryTrack = track
        }
    }


    @ViewBuilder
    private func playbackActions(_ track: LibraryTrack) -> some View {
        let supported = PlaybackItem(library: track) != nil
        Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
            feature.send(.playNextRequested(id: track.id))
        }.disabled(!supported)
        Button("Add to Queue", systemImage: "text.badge.plus") {
            feature.send(.enqueueRequested(id: track.id))
        }.disabled(!supported)
    }

    // MARK: - Remove

    private func removeButton(
        _ track:
            LibraryTrack
    ) -> some View {

        Button(
            role:
                .destructive
        ) {

            feature
                .send(
                    .removeRequested(
                        id:
                            track.id
                    )
                )

        } label: {

            Label(
                "Remove from Library",
                systemImage:
                    "trash"
            )
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
                lhs,
                rhs in

                lhs.rawValue
                    < rhs.rawValue
            }


        HStack(
            spacing:
                4
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
                    .caption2
                        .weight(
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

            return
                "LOCAL"


        case .openverse:

            return
                "OPENVERSE"


        case .jamendo:

            return
                "JAMENDO"


        case .appleMusic:

            return
                "APPLE"


        case .openSubsonic:

            return
                "SUBSONIC"
        }
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(
        _ track:
            LibraryTrack
    ) -> some View {

        if
            let data =
                track.artworkData {

            localArtwork(
                data
            )


        } else if
            let url =
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
    private func localArtwork(_ data: Data) -> some View {
        if let image = Image(artworkData: data) {
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
                .title2
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}

#Preview("Saved Library · Empty") {
    @Previewable @State var selectedTrack: LocalTrack?
    let scene = MSRUPreviewData.makeScene(section: .library)
    LibraryView(feature: scene.libraryFeature, localStore: scene.application.localLibrary,
                playback: scene.application.playback, selectedLocalTrack: $selectedTrack, onAddMusic: {})
        .frame(width: 900, height: 650)
}

#Preview("Saved Library · Content") {
    @Previewable @State var selectedTrack: LocalTrack?
    let application = MSRUPreviewData.makeApplication(
        savedTracks: MSRUPreviewData.localTracks.map { LibraryTrack(local: $0) })
    let scene = SceneModel(application: application, section: .library)
    LibraryView(feature: scene.libraryFeature, localStore: application.localLibrary,
                playback: application.playback, selectedLocalTrack: $selectedTrack, onAddMusic: {})
        .frame(width: 900, height: 650)
        .task { await application.library.load() }
}

#Preview("Library · Compact") {
    let scene = MSRUPreviewData.makeScene(section: .library)
    LibraryView(feature: scene.libraryFeature, localStore: scene.application.localLibrary,
        playback: scene.application.playback, selectedLocalTrack: .constant(nil), onAddMusic: {})
        .frame(width: 360, height: 640)
}
