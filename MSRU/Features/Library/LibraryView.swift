//
//  LibraryView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI


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

    @State
    private var isDropTargeted:
        Bool = false


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

        Group {
            switch viewMode {
            case .grid:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        Divider()
                        filterBar
                        Divider()
                        errorBanners

                        switch scope {
                        case .saved:
                            savedGridContent
                        case .local:
                            localGridContent
                        }
                    }
                    .padding(24)
                }
                .hideScrollIndicatorsCompletely()

            case .table:
                VStack(spacing: 0) {
                    header
                    Divider()
                    filterBar
                    Divider()
                    errorBanners

                    switch scope {
                    case .saved:
                        savedTableContent
                    case .local:
                        localTableContent
                    }
                }
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
        .dropDestination(for: URL.self) { urls, _ in
            Task {
                await localStore.importFiles(urls)
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
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
        Picker("LibraryView", selection: $scope) {
            ForEach(Scope.allCases) { scope in Text(LocalizedStringKey(scope.title)).tag(scope) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var importButton: some View {
        Button(action: onAddMusic) { Label("Add Music", systemImage: "plus") }
    }

    private var librarySubtitle:
        String {

        switch scope {

        case .saved:

            return
                "\(feature.tracks.count) saved songs"


        case .local:

            return
                "\(localStore.tracks.count) local songs"
        }
    }


    // MARK: - Filter Bar

    private var filterBar: some View {
        LibraryFilterBar(
            viewMode: $viewMode,
            sortField: $sortField,
            sortAscending: $sortAscending,
            searchQuery: $searchQuery
        )
    }

    // MARK: - Error Banners

    @ViewBuilder
    private var errorBanners: some View {
        if let error = feature.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label(error, systemImage: "exclamationmark.triangle")
                Button("Reload Library") { Task { await feature.libraryStore.load() } }
            }
            .font(.callout)
            .padding(.horizontal, 20)
        }
        if let error = playback.playbackErrorMessage {
            Label(error, systemImage: "speaker.slash")
                .font(.callout)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Filtered Queries

    private var filteredSavedTracks: [LibraryTrack] {
        LibraryCollectionSortFilter.filterAndSort(
            tracks: feature.tracks,
            query: searchQuery,
            field: sortField,
            ascending: sortAscending
        )
    }

    private var filteredLocalTracks: [LocalTrack] {
        LibraryCollectionSortFilter.filterAndSort(
            tracks: localStore.tracks,
            query: searchQuery,
            field: sortField,
            ascending: sortAscending
        )
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 180, maximum: 200), spacing: 20)]
    }

    // MARK: - Grid Contents

    @ViewBuilder
    private var savedGridContent: some View {
        if feature.isLoading {
            loadingView
        } else if feature.tracks.isEmpty {
            emptySavedView
        } else if filteredSavedTracks.isEmpty {
            emptySearchView
        } else {
            LazyVGrid(columns: gridColumns, spacing: 24) {
                ForEach(filteredSavedTracks) { track in
                    LibrarySavedTrackCardItemView(
                        track: track,
                        isRemoving: feature.isRemoving(track),
                        isSelected: selectedLibraryTrack?.id == track.id,
                        isPlaying: playback.currentItem?.id == PlaybackItem(library: track)?.id && playback.isPlaying,
                        onSelect: { selectedLibraryTrack = track },
                        onPlay: { feature.send(.playRequested(id: track.id)) },
                        onPlayNext: { feature.send(.playNextRequested(id: track.id)) },
                        onEnqueue: { feature.send(.enqueueRequested(id: track.id)) },
                        onRemove: { feature.send(.removeRequested(id: track.id)) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var localGridContent: some View {
        if localStore.isLoading {
            loadingView
        } else if localStore.tracks.isEmpty {
            emptyLocalView
        } else if filteredLocalTracks.isEmpty {
            emptySearchView
        } else {
            LazyVGrid(columns: gridColumns, spacing: 24) {
                ForEach(filteredLocalTracks) { track in
                    LibraryLocalTrackCardItemView(
                        track: track,
                        isSelected: selectedLocalTrack?.id == track.id,
                        isPlaying: playback.isPlaying(trackID: track.id),
                        isSaved: feature.libraryStore.contains(local: track),
                        onSelect: { selectedLocalTrack = track },
                        onPlay: { playback.toggle(track: track, queue: localStore.tracks) },
                        onPlayNext: { playback.playNext(track) },
                        onEnqueue: { playback.addToQueue(track) },
                        onToggleLibrary: {
                            Task {
                                if feature.libraryStore.contains(local: track) {
                                    await feature.libraryStore.remove(local: track)
                                } else {
                                    await feature.libraryStore.add(local: track)
                                }
                            }
                        },
                        onReveal: { PlatformFileViewer.revealInFinder(url: track.fileURL) },
                        onDelete: {
                            Task {
                                await localStore.deleteTracks(withIDs: [track.id])
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Table Contents

    @ViewBuilder
    private var savedTableContent: some View {
        if feature.isLoading {
            loadingView
        } else if feature.tracks.isEmpty {
            emptySavedView
        } else if filteredSavedTracks.isEmpty {
            emptySearchView
        } else {
            LibraryTrackTableView(
                tracks: filteredSavedTracks,
                selectedTrack: $selectedLibraryTrack,
                playback: playback,
                library: feature.libraryStore
            )
        }
    }

    @ViewBuilder
    private var localTableContent: some View {
        if localStore.isLoading {
            loadingView
        } else if localStore.tracks.isEmpty {
            emptyLocalView
        } else if filteredLocalTracks.isEmpty {
            emptySearchView
        } else {
            LocalTrackTableView(
                tracks: filteredLocalTracks,
                positionLookup: localStore.positionLookup,
                isFiltered: !searchQuery.isEmpty,
                selectedTrack: $selectedLocalTrack,
                playback: playback,
                library: feature.libraryStore,
                onRevealInFinder: { url in
                    PlatformFileViewer.revealInFinder(url: url)
                },
                onDeleteTracks: { ids in
                    Task {
                        await localStore.deleteTracks(withIDs: ids)
                    }
                }
            )
        }
    }

    // MARK: - Empty & Loading Views

    private var emptySavedView: some View {
        ContentUnavailableView {
            Label("Library is empty", systemImage: "music.note.house")
        } description: {
            Text("Add songs from Browse or local files.")
        } actions: {
            Button("Add Music") { onAddMusic() }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var emptyLocalView: some View {
        ContentUnavailableView {
            Label("No Local Music", systemImage: "externaldrive")
        } description: {
            Text("Import audio files, or drag files into MSRU.")
        } actions: {
            Button("Add Music") { onAddMusic() }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var emptySearchView: some View {
        ContentUnavailableView.search(text: searchQuery)
            .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading library…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }


    // MARK: - Card Views

    private struct LibrarySavedTrackCardItemView: View {
        let track: LibraryTrack
        let isRemoving: Bool
        let isSelected: Bool
        let isPlaying: Bool
        let onSelect: () -> Void
        let onPlay: () -> Void
        let onPlayNext: () -> Void
        let onEnqueue: () -> Void
        let onRemove: () -> Void

        @State private var isHovered: Bool = false

        private var durationText: String? {
            track.duration.map { duration in
                let seconds = max(0, Int(duration.rounded()))
                return String(format: "%d:%02d", seconds / 60, seconds % 60)
            }
        }

        var body: some View {
            UnifiedTrackCardView(
                title: track.title,
                subtitle: track.artist,
                secondaryText: track.album,
                durationText: durationText,
                qualityBadge: track.sources.first?.kind.rawValue.uppercased(),
                isPlaying: isPlaying,
                isSelected: isSelected,
                onSelect: onSelect,
                onPlay: onPlay
            ) {
                MediaImageView(
                    reference: track.artworkReference,
                    thumbnailPixelSize: CGSize(width: 240, height: 240),
                    placeholderSystemImage: "music.note",
                    cornerRadius: 10
                )
            } actionsMenu: {
                if isRemoving {
                    ProgressView()
                        .controlSize(.small)
                } else if isHovered {
                    Menu {
                        menuContent
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 22, height: 18)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                } else {
                    Color.clear
                        .frame(width: 22, height: 18)
                }
            }
            .frame(height: 236)
            .contextMenu {
                menuContent
            }
            .onHover { hovering in
                if isHovered != hovering {
                    isHovered = hovering
                }
            }
        }

        @ViewBuilder
        private var menuContent: some View {
            let supported = PlaybackItem(library: track) != nil
            Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward", action: onPlayNext)
                .disabled(!supported)
            Button("Add to Queue", systemImage: "text.badge.plus", action: onEnqueue)
                .disabled(!supported)
            if !isRemoving {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove from Library", systemImage: "trash")
                }
            }
        }
    }

    private struct LibraryLocalTrackCardItemView: View {
        let track: LocalTrack
        let isSelected: Bool
        let isPlaying: Bool
        let isSaved: Bool
        let onSelect: () -> Void
        let onPlay: () -> Void
        let onPlayNext: () -> Void
        let onEnqueue: () -> Void
        let onToggleLibrary: () -> Void
        let onReveal: () -> Void
        let onDelete: () -> Void

        @State private var isHovered: Bool = false

        private var durationText: String {
            let seconds = max(0, Int(track.duration.rounded()))
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }

        var body: some View {
            UnifiedTrackCardView(
                title: track.title,
                subtitle: track.artist,
                secondaryText: track.album,
                durationText: durationText,
                qualityBadge: track.fileURL.pathExtension.uppercased(),
                isPlaying: isPlaying,
                isSelected: isSelected,
                onSelect: onSelect,
                onPlay: onPlay
            ) {
                MediaImageView(
                    reference: track.artworkReference,
                    thumbnailPixelSize: CGSize(width: 240, height: 240),
                    placeholderSystemImage: "music.note",
                    cornerRadius: 10
                )
            } actionsMenu: {
                HStack(spacing: 4) {
                    if isSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.caption)
                    }

                    if isHovered {
                        Menu {
                            menuContent
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 22, height: 18)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    } else {
                        Color.clear
                            .frame(width: 22, height: 18)
                    }
                }
            }
            .frame(height: 236)
            .contextMenu {
                menuContent
            }
            .onHover { hovering in
                if isHovered != hovering {
                    isHovered = hovering
                }
            }
        }

        @ViewBuilder
        private var menuContent: some View {
            Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward", action: onPlayNext)
            Button("Add to Queue", systemImage: "text.badge.plus", action: onEnqueue)
            Divider()
            Button(action: onToggleLibrary) {
                Label(
                    isSaved ? "Remove from Library" : "Add to Library",
                    systemImage: isSaved ? "heart.slash" : "heart"
                )
            }
            Divider()
            Button("Show in Finder", systemImage: "folder", action: onReveal)
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete from Library", systemImage: "trash")
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

    private func artwork(_ track: LibraryTrack) -> some View {
        MediaImageView(
            reference: track.artworkReference ?? track.artworkURL?.absoluteString,
            thumbnailPixelSize: CGSize(width: 240, height: 240),
            placeholderSystemImage: "music.note",
            cornerRadius: 10
        )
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
