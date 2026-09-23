//
//  LibraryView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MediaLibrary
import SubsonicKit


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
                    "Files"
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

    var subsonicServers:
        SubsonicServerStore? = nil

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

    @State private var debouncedLocalQuery = ""
    @State private var localPager: LocalTrackPager? = nil

    @State
    private var isDropTargeted:
        Bool = false

    @State
    private var selectedSavedTrackIDs: Set<UUID> = []

    @State
    private var selectedLocalTrackIDs: Set<String> = []

    @State
    private var isDeleteConfirmationPresented: Bool = false

    @Binding var selectedSourceID: String?
    @State private var availableSources: [SourceFilterItem] = []
    @State private var remoteTracks: [LocalTrack] = []
    @State private var isLoadingRemoteTracks: Bool = false
    @State private var remoteAlbumOffset: Int = 0
    @State private var hasMoreRemoteTracks: Bool = true
    @State private var isLoadingMoreRemoteTracks: Bool = false
    @State private var isSearchingRemoteTracks: Bool = false
    private let albumBatchSize: Int = 10

    // MARK: - Init

    init(
        feature:
            FeatureHost<LibraryFeature>,
        localStore:
            LocalLibraryStore,
        subsonicServers:
            SubsonicServerStore? = nil,
        playback:
            PlaybackController,
        selectedLocalTrack:
            Binding<LocalTrack?>,
        selectedLibraryTrack:
            Binding<LibraryTrack?> = .constant(nil),
        selectedSourceID:
            Binding<String?> = .constant(nil),
        onAddMusic:
            @escaping () -> Void
    ) {
        self.feature = feature
        self.localStore = localStore
        self.subsonicServers = subsonicServers
        self.playback = playback
        self._selectedLocalTrack = selectedLocalTrack
        self._selectedLibraryTrack = selectedLibraryTrack
        self._selectedSourceID = selectedSourceID
        self.onAddMusic = onAddMusic
    }


    // MARK: - Body

    var body: some View {
        Group {
            switch viewMode {
            case .grid:
                gridModeView
            case .table:
                tableModeView
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
        .confirmationDialog(
            "Delete selected songs?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove from Library (\(selectedLocalTrackIDs.count) items)", role: .destructive) {
                Task {
                    await localStore.deleteTracks(withIDs: selectedLocalTrackIDs)
                    selectedLocalTrackIDs.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected songs will be removed from local library. Original files will remain on disk.")
        }
        .onChange(of: selectedSavedTrackIDs) { _, newIDs in
            if newIDs.count == 1, let found = filteredSavedTracks.first(where: { $0.id == newIDs.first }) {
                selectedLibraryTrack = found
            } else if newIDs.isEmpty {
                selectedLibraryTrack = nil
            }
        }
        .onChange(of: selectedLocalTrackIDs) { _, newIDs in
            if newIDs.count == 1, let found = filteredLocalTracks.first(where: { $0.id == newIDs.first }) {
                selectedLocalTrack = found
            } else if newIDs.isEmpty {
                selectedLocalTrack = nil
            }
        }
        .task {
            availableSources = (try? await LibraryQueryEngine.shared.fetchAvailableSources(for: "recording")) ?? []
            if let servers = subsonicServers?.servers {
                for server in servers {
                    let sourceID = "src_\(server.id.rawValue)"
                    if !availableSources.contains(where: { $0.sourceID == sourceID || $0.sourceID == server.id.rawValue }) {
                        availableSources.append(
                            SourceFilterItem(
                                id: sourceID,
                                displayName: server.name,
                                count: nil
                            )
                        )
                    }
                }
            }
        }
        .task(id: selectedSourceID) {
            if isRemoteSourceActive, let sourceID = selectedSourceID {
                await loadRemoteTracks(sourceID: sourceID, query: searchQuery, reset: true)
            }
        }
        .task(id: "\(selectedSourceID ?? "")-\(searchQuery)") {
            if isRemoteSourceActive, let sourceID = selectedSourceID {
                let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await loadRemoteTracks(sourceID: sourceID, query: trimmed, reset: true)
            }
        }
        .task(id: searchQuery) {
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
            }
            debouncedLocalQuery = trimmed
        }
        .task(id: "\(scope.rawValue)|\(selectedSourceID ?? "")|\(debouncedLocalQuery)|\(sortField.rawValue)|\(sortAscending)|\(localStore.revision)") {
            guard scope == .local, !isRemoteSourceActive else { return }
            let pager = localPager ?? localStore.makePager()
            localPager = pager
            await pager.reset(
                query: debouncedLocalQuery,
                sort: LocalTrackPageRequest.Sort(rawValue: sortField.rawValue) ?? .title,
                ascending: sortAscending
            )
        }
    }

    // MARK: - View Mode Layouts

    @ViewBuilder
    private var gridOverlayBar: some View {
        if scope == .saved && selectedSavedTrackIDs.count > 1 {
            savedGridBatchBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if scope == .local && selectedLocalTrackIDs.count > 1 {
            localGridBatchBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var gridModeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                filterBar
                Divider()
                errorBanners

                if isRemoteSourceActive {
                    localGridContent

                    if isLoadingMoreRemoteTracks {
                        HStack(spacing: 8) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在加载更多曲目...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                } else {
                    switch scope {
                    case .saved:
                        savedGridContent
                    case .local:
                        localGridContent
                    }
                }
            }
            .padding(24)
        }
        .hideScrollIndicatorsCompletely()
        .overlay(alignment: .bottom) {
            gridOverlayBar
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSavedTrackIDs.count)
        .animation(.easeInOut(duration: 0.2), value: selectedLocalTrackIDs.count)
    }

    @ViewBuilder
    private var tableModeView: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            Divider()
            errorBanners

            if isRemoteSourceActive {
                localTableContent

                if isLoadingMoreRemoteTracks {
                    HStack(spacing: 8) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在加载更多曲目...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            } else {
                switch scope {
                case .saved:
                    savedTableContent
                case .local:
                    localTableContent
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                libraryTitle
                Spacer()
                if !isRemoteSourceActive {
                    scopePicker.frame(width: 220)
                }
                importButton
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    libraryTitle
                    Spacer()
                    importButton
                }
                if !isRemoteSourceActive {
                    scopePicker
                }
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

    private var librarySubtitle: String {
        if isRemoteSourceActive {
            if isLoadingRemoteTracks && remoteTracks.isEmpty {
                return String(localized: "正在从远程媒体服务加载…")
            }
            if isSearchingRemoteTracks {
                return String(localized: "正在检索远程歌曲…")
            }
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                return "搜索结果：\(filteredLocalTracks.count) 首歌曲"
            }
            let serverName = availableSources.first(where: { $0.sourceID == selectedSourceID })?.displayName ?? "远程媒体服务"
            return "\(serverName) • 按需在线浏览"
        }
        switch scope {
        case .saved:
            return "\(feature.tracks.count) 首收藏歌曲"
        case .local:
            return "\(localPager?.totalCount ?? 0) 首本地歌曲"
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            LibraryFilterBar(
                viewMode: $viewMode,
                sortField: $sortField,
                sortAscending: $sortAscending,
                searchQuery: $searchQuery,
                isSearching: isSearchingRemoteTracks,
                prompt: isRemoteSourceActive ? "搜索远程歌曲…" : "Filter songs…"
            )

            if !availableSources.isEmpty {
                SourceFilterBarView(sources: availableSources, selectedSourceID: $selectedSourceID)
                    .padding(.horizontal, 20)
            }
        }
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
        if let error = localPager?.errorMessage, scope == .local, !isRemoteSourceActive {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Filtered Queries

    private var filteredSavedTracks: [LibraryTrack] {
        var baseTracks = feature.tracks
        if let selectedSourceID {
            baseTracks = baseTracks.filter { track in
                if SourceID.isLocalSourceID(selectedSourceID) {
                    return track.sources.contains(where: { $0.kind == .local })
                } else {
                    return track.sources.contains(where: { $0.kind == .openSubsonic })
                }
            }
        }
        return LibraryCollectionSortFilter.filterAndSort(
            tracks: baseTracks,
            query: searchQuery,
            field: sortField,
            ascending: sortAscending
        )
    }

    private var isRemoteSourceActive: Bool {
        guard let id = selectedSourceID else { return false }
        return !SourceID.isLocalSourceID(id)
    }

    private func loadRemoteTracks(sourceID: String, query: String = "", reset: Bool = true) async {
        guard !SourceID.isLocalSourceID(sourceID), let subsonicServers else { return }
        let cleanID = sourceID.replacingOccurrences(of: "src_", with: "")
        guard let server = subsonicServers.servers.first(where: {
            $0.id.rawValue == sourceID || $0.id.rawValue == cleanID
        }),
        let client = subsonicServers.client(for: server.id) else {
            return
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if reset {
            if !trimmed.isEmpty {
                isSearchingRemoteTracks = true
            } else {
                isLoadingRemoteTracks = true
            }
            remoteAlbumOffset = 0
            hasMoreRemoteTracks = true
            remoteTracks = []
        } else {
            guard hasMoreRemoteTracks, !isLoadingMoreRemoteTracks, !isLoadingRemoteTracks, !isSearchingRemoteTracks else { return }
            isLoadingMoreRemoteTracks = true
        }

        defer {
            isLoadingRemoteTracks = false
            isLoadingMoreRemoteTracks = false
            isSearchingRemoteTracks = false
        }

        do {
            var songs: [SubsonicSongDTO] = []
            if !trimmed.isEmpty {
                let searchResult = try await client.search3(query: trimmed, artistCount: 0, albumCount: 0, songCount: 100)
                songs = searchResult.song ?? []
                self.hasMoreRemoteTracks = false
            } else {
                let albumList = try await client.albumList2(type: "alphabeticalByName", size: albumBatchSize, offset: remoteAlbumOffset)
                for album in albumList {
                    if let albumDetail = try? await client.album(id: album.id),
                       let albumSongs = albumDetail.song {
                        songs.append(contentsOf: albumSongs)
                    }
                }
                self.remoteAlbumOffset += albumList.count
                if albumList.count < albumBatchSize {
                    self.hasMoreRemoteTracks = false
                }
            }

            let mapped: [LocalTrack] = songs.compactMap { song in
                guard let streamURL = try? client.streamURL(id: song.id) else { return nil }
                let coverURL = try? client.coverArtURL(id: song.coverArt ?? song.id)
                return LocalTrack(
                    fileURL: streamURL,
                    title: song.title,
                    artist: song.artist ?? "Unknown Artist",
                    album: song.album ?? "Unknown Album",
                    duration: TimeInterval(song.duration ?? 0),
                    artworkReference: coverURL?.absoluteString,
                    trackNumber: song.track,
                    year: song.year
                )
            }

            if reset {
                self.remoteTracks = mapped
            } else {
                self.remoteTracks.append(contentsOf: mapped)
            }
        } catch is CancellationError {
            // Cancelled
        } catch {
            print("[LibraryView] Failed to load remote tracks: \(error)")
        }
    }

    private var filteredLocalTracks: [LocalTrack] {
        if isRemoteSourceActive {
            return remoteTracks
        }
        return localPager?.tracks ?? []
    }

    private func playLocalPageTrack(_ track: LocalTrack, queue: [LocalTrack]) {
        playback.toggle(track: track, queue: queue)
        if !isRemoteSourceActive {
            playback.continueLocalQueue(using: localPager?.makePlaybackPageSource())
        }
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
            MarqueeSelectionContainer(selectedIDs: $selectedSavedTrackIDs) {
                LazyVGrid(columns: gridColumns, spacing: 24) {
                    ForEach(filteredSavedTracks) { track in
                        LibrarySavedTrackCardItemView(
                            track: track,
                            isRemoving: feature.isRemoving(track),
                            isSelected: selectedSavedTrackIDs.contains(track.id) || selectedLibraryTrack?.id == track.id,
                            isPlaying: playback.currentItem?.id == PlaybackItem(library: track)?.id && playback.isPlaying,
                            onSelect: {
                                SelectionHelper.handleTap(
                                    for: track.id,
                                    selectedIDs: $selectedSavedTrackIDs,
                                    allIDs: filteredSavedTracks.map(\.id)
                                )
                                if selectedSavedTrackIDs.count == 1, let found = filteredSavedTracks.first(where: { $0.id == selectedSavedTrackIDs.first }) {
                                    selectedLibraryTrack = found
                                } else if selectedSavedTrackIDs.isEmpty {
                                    selectedLibraryTrack = nil
                                }
                            },
                            onPlay: { feature.send(.playRequested(id: track.id)) },
                            onPlayNext: { feature.send(.playNextRequested(id: track.id)) },
                            onEnqueue: { feature.send(.enqueueRequested(id: track.id)) },
                            onRemove: { feature.send(.removeRequested(id: track.id)) }
                        )
                        .marqueeItem(id: track.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var localGridContent: some View {
        if (isRemoteSourceActive && isLoadingRemoteTracks && remoteTracks.isEmpty) || isSearchingRemoteTracks {
            loadingView
        } else if !isRemoteSourceActive && localStore.isLoading {
            loadingView
        } else if !isRemoteSourceActive && (localPager == nil || (localPager?.isLoading == true && localPager?.tracks.isEmpty == true)) {
            loadingView
        } else if isRemoteSourceActive && remoteTracks.isEmpty {
            remoteEmptyView
        } else if !isRemoteSourceActive && (localPager?.totalCount ?? 0) == 0 {
            emptyLocalView
        } else if filteredLocalTracks.isEmpty {
            emptySearchView
        } else {
            MarqueeSelectionContainer(selectedIDs: $selectedLocalTrackIDs) {
                LazyVGrid(columns: gridColumns, spacing: 24) {
                    ForEach(filteredLocalTracks) { track in
                        LibraryLocalTrackCardItemView(
                            track: track,
                            isSelected: selectedLocalTrackIDs.contains(track.id) || selectedLocalTrack?.id == track.id,
                            isPlaying: playback.isPlaying(trackID: track.id),
                            isSaved: feature.libraryStore.contains(local: track),
                            onSelect: {
                                SelectionHelper.handleTap(
                                    for: track.id,
                                    selectedIDs: $selectedLocalTrackIDs,
                                    allIDs: filteredLocalTracks.map(\.id)
                                )
                                if selectedLocalTrackIDs.count == 1, let found = filteredLocalTracks.first(where: { $0.id == selectedLocalTrackIDs.first }) {
                                    selectedLocalTrack = found
                                } else if selectedLocalTrackIDs.isEmpty {
                                    selectedLocalTrack = nil
                                }
                            },
                            onPlay: { playLocalPageTrack(track, queue: filteredLocalTracks) },
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
                            onReveal: {
                                if track.fileURL.isFileURL {
                                    PlatformFileViewer.revealInFinder(url: track.fileURL)
                                }
                            },
                            onDelete: {
                                if !isRemoteSourceActive {
                                    Task {
                                        await localStore.deleteTracks(withIDs: [track.id])
                                    }
                                }
                            }
                        )
                        .marqueeItem(id: track.id)
                        .onAppear {
                            if isRemoteSourceActive && track.id == remoteTracks.last?.id && hasMoreRemoteTracks && !isLoadingMoreRemoteTracks && !isLoadingRemoteTracks && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if let sourceID = selectedSourceID {
                                    Task {
                                        await loadRemoteTracks(sourceID: sourceID, query: "", reset: false)
                                    }
                                }
                            } else if !isRemoteSourceActive && track.id == localPager?.tracks.last?.id && localPager?.hasMore == true {
                                Task { await localPager?.loadMore() }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grid Batch Bars

    @ViewBuilder
    private var savedGridBatchBar: some View {
        FloatingBatchBar(
            count: selectedSavedTrackIDs.count,
            title: "\(selectedSavedTrackIDs.count) songs",
            onDeselect: { selectedSavedTrackIDs.removeAll() }
        ) {
            Button {
                let selected = filteredSavedTracks.filter { selectedSavedTrackIDs.contains($0.id) }
                if let first = selected.first {
                    feature.send(.playRequested(id: first.id))
                    for track in selected.dropFirst() {
                        feature.send(.enqueueRequested(id: track.id))
                    }
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredSavedTracks.filter { selectedSavedTrackIDs.contains($0.id) }
                for track in selected {
                    feature.send(.enqueueRequested(id: track.id))
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                let selected = filteredSavedTracks.filter { selectedSavedTrackIDs.contains($0.id) }
                for track in selected {
                    feature.send(.removeRequested(id: track.id))
                }
                selectedSavedTrackIDs.removeAll()
            } label: {
                Label("Remove from Library", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var localGridBatchBar: some View {
        FloatingBatchBar(
            count: selectedLocalTrackIDs.count,
            title: "\(selectedLocalTrackIDs.count) songs",
            onDeselect: { selectedLocalTrackIDs.removeAll() }
        ) {
            Button {
                let selected = filteredLocalTracks.filter { selectedLocalTrackIDs.contains($0.id) }
                if let first = selected.first {
                    playback.toggle(track: first, queue: selected)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredLocalTracks.filter { selectedLocalTrackIDs.contains($0.id) }
                for track in selected {
                    playback.addToQueue(track)
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            } label: {
                Label("Delete from Library", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
        if (isRemoteSourceActive && isLoadingRemoteTracks && remoteTracks.isEmpty) || isSearchingRemoteTracks {
            loadingView
        } else if !isRemoteSourceActive && localStore.isLoading {
            loadingView
        } else if !isRemoteSourceActive && (localPager == nil || (localPager?.isLoading == true && localPager?.tracks.isEmpty == true)) {
            loadingView
        } else if isRemoteSourceActive && remoteTracks.isEmpty {
            remoteEmptyView
        } else if !isRemoteSourceActive && (localPager?.totalCount ?? 0) == 0 {
            emptyLocalView
        } else if filteredLocalTracks.isEmpty {
            emptySearchView
        } else {
            LocalTrackTableView(
                tracks: filteredLocalTracks,
                positionLookup: nil,
                isFiltered: !searchQuery.isEmpty || isRemoteSourceActive,
                selectedTrack: $selectedLocalTrack,
                playback: playback,
                library: feature.libraryStore,
                onRevealInFinder: { url in
                    if url.isFileURL {
                        PlatformFileViewer.revealInFinder(url: url)
                    }
                },
                onDeleteTracks: { ids in
                    if !isRemoteSourceActive {
                        Task {
                            await localStore.deleteTracks(withIDs: ids)
                        }
                    }
                },
                onTrackAppear: { track in
                    if isRemoteSourceActive && track.id == remoteTracks.last?.id && hasMoreRemoteTracks && !isLoadingMoreRemoteTracks && !isLoadingRemoteTracks && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let sourceID = selectedSourceID {
                            Task {
                                await loadRemoteTracks(sourceID: sourceID, query: "", reset: false)
                            }
                        }
                    } else if !isRemoteSourceActive && track.id == localPager?.tracks.last?.id && localPager?.hasMore == true {
                        Task { await localPager?.loadMore() }
                    }
                },
                onPlay: { track, queue in playLocalPageTrack(track, queue: queue) }
            )
        }
    }

    // MARK: - Empty & Loading Views

    private var remoteEmptyView: some View {
        ContentUnavailableView {
            Label(
                searchQuery.isEmpty ? "未发现远程歌曲" : "未找到匹配曲目",
                systemImage: searchQuery.isEmpty ? "externaldrive.connected.to.line.below" : "magnifyingglass"
            )
        } description: {
            Text(searchQuery.isEmpty ? "远程媒体服务已连接，当前暂未发现歌曲，或可尝试在上方的搜索框中搜索曲目。" : "未在远程服务器中找到与 \"\(searchQuery)\" 匹配的歌曲。")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

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
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("Try searching for a different song, artist, or album.")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(isSearchingRemoteTracks ? "正在远程检索歌曲..." : (isRemoteSourceActive ? "正在从远程媒体服务加载歌曲..." : "Loading library…"))
                .foregroundStyle(.secondary)
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
