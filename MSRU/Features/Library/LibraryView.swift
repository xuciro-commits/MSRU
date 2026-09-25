//
//  LibraryView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import SubsonicKit
import MusicLibrary
import MusicPlayback


struct LibraryView:
    View {

    /// Filter item for tracks saved from Browse (Openverse and other web
    /// providers). They are library members without a file or server source.
    static let webSourceID = "web"


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



    let onAddMusic:
        () -> Void

    let onOpenCleanup:
        () -> Void


    // MARK: - Local UI State

    @State
    private var viewMode:
        LibraryViewMode = .table

    @State
    private var sortField:
        LibrarySortField = .dateAdded

    @State
    private var sortAscending:
        Bool = false

    @Binding
    var searchQuery:
        String

    @State private var debouncedLocalQuery = ""
    @State private var localPager: LocalTrackPager? = nil

    @State
    private var isDropTargeted:
        Bool = false

    @State
    private var selectedLocalTrackIDs: Set<String> = []

    @State
    private var isDeleteConfirmationPresented: Bool = false

    @State
    private var metadataEditTracks: [LocalTrack]? = nil

    @State
    private var isRefreshingMetadata: Bool = false

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
        searchQuery:
            Binding<String> = .constant(""),
        selectedLocalTrack:
            Binding<LocalTrack?>,
        selectedSourceID:
            Binding<String?> = .constant(nil),
        onAddMusic:
            @escaping () -> Void,
        onOpenCleanup:
            @escaping () -> Void = {}
    ) {
        self.feature = feature
        self.localStore = localStore
        self.subsonicServers = subsonicServers
        self.playback = playback
        self._searchQuery = searchQuery
        self._selectedLocalTrack = selectedLocalTrack
        self._selectedSourceID = selectedSourceID
        self.onAddMusic = onAddMusic
        self.onOpenCleanup = onOpenCleanup
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
            "Remove selected songs from the Library?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove from Library (\(selectedLocalTrackIDs.count) items)", role: .destructive) {
                removeFromLibrary(selectedLocalTrackIDs)
                selectedLocalTrackIDs.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The songs leave the Library. Files stay on disk.")
        }
        .onChange(of: selectedLocalTrackIDs) { _, newIDs in
            if newIDs.count == 1, let found = filteredLocalTracks.first(where: { $0.id == newIDs.first }) {
                selectedLocalTrack = found
            } else if newIDs.isEmpty {
                selectedLocalTrack = nil
            }
        }
        .task {
            let servers = subsonicServers?.servers.map { ($0.id.rawValue, $0.name) } ?? []
            availableSources = (try? await localStore.availableSources(for: "recording", additionalRemoteServers: servers)) ?? []
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
        .task(id: "\(selectedSourceID ?? "")|\(debouncedLocalQuery)|\(sortField.rawValue)|\(sortAscending)") {
            guard !isWebSourceActive, !isRemoteSourceActive else { return }
            let pager = localPager ?? localStore.makePager()
            localPager = pager
            await pager.reset(
                query: debouncedLocalQuery,
                sort: LocalTrackPageRequest.Sort(rawValue: sortField.rawValue) ?? .title,
                ascending: sortAscending,
                sourceFilter: selectedSourceID
            )
        }
        .onChange(of: localStore.revision) { _, _ in
            guard !isWebSourceActive, !isRemoteSourceActive else { return }
            guard let pager = localPager else { return }
            Task {
                await pager.reload(preserveCount: true)
            }
        }
        .sheet(isPresented: Binding(
            get: { metadataEditTracks != nil },
            set: { if !$0 { metadataEditTracks = nil } }
        )) {
            if let tracks = metadataEditTracks {
                MetadataEditorSheet(
                    tracks: tracks,
                    localStore: localStore,
                    onDismiss: { metadataEditTracks = nil }
                )
            }
        }
    }

    // MARK: - View Mode Layouts

    @ViewBuilder
    private var gridOverlayBar: some View {
        if selectedLocalTrackIDs.count > 1 {
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
                    localGridContent
                }
            }
            .padding(24)
        }
        .hideScrollIndicatorsCompletely()
        .overlay(alignment: .bottom) {
            gridOverlayBar
        }
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
                localTableContent
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                libraryTitle
                Spacer()
                importButton
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    libraryTitle
                    Spacer()
                    importButton
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
        if isWebSourceActive {
            return "\(webTracks.count) 首网络歌曲"
        }
        return "\(localPager?.totalCount ?? 0) 首歌曲"
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
                showsSearch: false,
                prompt: isRemoteSourceActive ? "搜索远程歌曲…" : "Filter songs…",
                onOpenCleanup: onOpenCleanup
            )

            if sourceFilterItems.count > 1 {
                SourceFilterBarView(sources: sourceFilterItems, selectedSourceID: $selectedSourceID)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Error Banners

    @ViewBuilder
    private var errorBanners: some View {
        if let error = feature.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .padding(.horizontal, 20)
        }
        if let error = playback.playbackErrorMessage {
            Label(error, systemImage: "speaker.slash")
                .font(.callout)
                .padding(.horizontal, 20)
        }
        if let error = localPager?.errorMessage, !isWebSourceActive, !isRemoteSourceActive {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Filtered Queries

    private var webTracks: [LocalTrack] {
        feature.webTracks
    }

    /// Paged index of local files; the default Library scope.
    private var isLocalPagerActive: Bool {
        !isWebSourceActive && !isRemoteSourceActive
    }

    /// Server tracks are browsed live and are not Library members to remove.
    private var canRemoveFromLibrary: Bool {
        !isRemoteSourceActive
    }

    /// One removal path: files leave the index (files stay on disk); web
    /// tracks leave the index.
    private func removeFromLibrary(_ ids: Set<String>) {
        if isWebSourceActive {
            feature.send(.removeWebTracksRequested(ids))
        } else {
            Task { await localStore.deleteTracks(withIDs: ids) }
        }
    }

    private var sourceFilterItems: [SourceFilterItem] {
        var items = availableSources
        if items.isEmpty {
            items.append(SourceFilterItem(id: nil, displayName: String(localized: "All"), count: nil))
        }
        if !webTracks.isEmpty {
            items.append(SourceFilterItem(id: Self.webSourceID, displayName: String(localized: "Web"), count: webTracks.count))
        }
        return items
    }

    private var sourceScope: SourceScope {
        SourceScope(sourceID: selectedSourceID)
    }

    private var isWebSourceActive: Bool {
        sourceScope.isWeb
    }

    private var isRemoteSourceActive: Bool {
        sourceScope.isRemote
    }

    private func loadRemoteTracks(sourceID: String, query: String = "", reset: Bool = true) async {
        guard !SourceID.isLocalSourceID(sourceID), let subsonicServers else { return }
        let serverID = SourceID(serverKeyOrSourceID: sourceID)
        guard let server = subsonicServers.servers.first(where: { $0.id == serverID }),
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
        if isWebSourceActive {
            return LibraryCollectionSortFilter.filterAndSort(
                tracks: webTracks, query: searchQuery, field: sortField, ascending: sortAscending)
        }
        if isRemoteSourceActive {
            return remoteTracks
        }
        return localPager?.tracks ?? []
    }

    private func playLocalPageTrack(_ track: LocalTrack, queue: [LocalTrack]) {
        playback.toggle(track: track, queue: queue)
        if isLocalPagerActive {
            playback.continueLocalQueue(using: localPager?.makePlaybackPageSource())
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 180, maximum: 200), spacing: 20)]
    }

    // MARK: - Grid Contents

    @ViewBuilder
    private var localGridContent: some View {
        if (isRemoteSourceActive && isLoadingRemoteTracks && remoteTracks.isEmpty) || isSearchingRemoteTracks {
            loadingView
        } else if isLocalPagerActive && localStore.isLoading {
            loadingView
        } else if isLocalPagerActive && (localPager == nil || (localPager?.isLoading == true && localPager?.tracks.isEmpty == true)) {
            loadingView
        } else if isRemoteSourceActive && remoteTracks.isEmpty {
            remoteEmptyView
        } else if isWebSourceActive && webTracks.isEmpty {
            emptyWebView
        } else if isLocalPagerActive && (localPager?.totalCount ?? 0) == 0 {
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
                            onReveal: {
                                if track.fileURL.isFileURL {
                                    PlatformFileViewer.revealInFinder(url: track.fileURL)
                                }
                            },
                            onRemove: canRemoveFromLibrary ? { removeFromLibrary([track.id]) } : nil,
                            onEditMetadata: {
                                if selectedLocalTrackIDs.contains(track.id) && selectedLocalTrackIDs.count > 1 {
                                    let selected = filteredLocalTracks.filter { selectedLocalTrackIDs.contains($0.id) }
                                    Task {
                                        isRefreshingMetadata = true
                                        defer { isRefreshingMetadata = false }
                                        if let updated = try? await localStore.refreshMetadata(for: selected) {
                                            localPager?.updateTracksInPlace(updated)
                                        }
                                    }
                                } else {
                                    metadataEditTracks = [track]
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
                            } else if isLocalPagerActive && track.id == localPager?.tracks.last?.id && localPager?.hasMore == true {
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

            if selectedLocalTrackIDs.count == 1 {
                Button {
                    let selected = filteredLocalTracks.filter { selectedLocalTrackIDs.contains($0.id) }
                    metadataEditTracks = selected
                } label: {
                    Label("Edit Info...", systemImage: "info.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if selectedLocalTrackIDs.count > 1 {
                Button {
                    let selected = filteredLocalTracks.filter { selectedLocalTrackIDs.contains($0.id) }
                    Task {
                        isRefreshingMetadata = true
                        defer { isRefreshingMetadata = false }
                        if let updated = try? await localStore.refreshMetadata(for: selected) {
                            localPager?.updateTracksInPlace(updated)
                        }
                    }
                } label: {
                    if isRefreshingMetadata {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 4)
                    } else {
                        Label("Get Info", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshingMetadata)
            }

            if canRemoveFromLibrary {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Table Contents

    @ViewBuilder
    private var localTableContent: some View {
        if (isRemoteSourceActive && isLoadingRemoteTracks && remoteTracks.isEmpty) || isSearchingRemoteTracks {
            loadingView
        } else if isLocalPagerActive && localStore.isLoading {
            loadingView
        } else if isLocalPagerActive && (localPager == nil || (localPager?.isLoading == true && localPager?.tracks.isEmpty == true)) {
            loadingView
        } else if isRemoteSourceActive && remoteTracks.isEmpty {
            remoteEmptyView
        } else if isWebSourceActive && webTracks.isEmpty {
            emptyWebView
        } else if isLocalPagerActive && (localPager?.totalCount ?? 0) == 0 {
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
                onRevealInFinder: { url in
                    if url.isFileURL {
                        PlatformFileViewer.revealInFinder(url: url)
                    }
                },
                onDeleteTracks: canRemoveFromLibrary ? { removeFromLibrary($0) } : nil,
                onEditMetadata: { tracks in
                    metadataEditTracks = tracks
                },
                onRefreshMetadata: { tracks in
                    if let updated = try? await localStore.refreshMetadata(for: tracks) {
                        localPager?.updateTracksInPlace(updated)
                    }
                },
                onTrackAppear: { track in
                    if isRemoteSourceActive && track.id == remoteTracks.last?.id && hasMoreRemoteTracks && !isLoadingMoreRemoteTracks && !isLoadingRemoteTracks && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let sourceID = selectedSourceID {
                            Task {
                                await loadRemoteTracks(sourceID: sourceID, query: "", reset: false)
                            }
                        }
                    } else if isLocalPagerActive && track.id == localPager?.tracks.last?.id && localPager?.hasMore == true {
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

    private var emptyWebView: some View {
        ContentUnavailableView {
            Label("No Web Songs", systemImage: "globe")
        } description: {
            Text("Songs you add to the Library from Browse appear here.")
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

    fileprivate struct LibraryLocalTrackCardItemView: View {
        let track: LocalTrack
        let isSelected: Bool
        let isPlaying: Bool
        let onSelect: () -> Void
        let onPlay: () -> Void
        let onPlayNext: () -> Void
        let onEnqueue: () -> Void
        let onReveal: () -> Void
        let onRemove: (() -> Void)?
        var onEditMetadata: (() -> Void)? = nil

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
            if track.fileURL.isFileURL {
                Divider()
                if let onEditMetadata {
                    Button("Get Info / Edit Metadata...", systemImage: "info.circle", action: onEditMetadata)
                }
                Button("Show in Finder", systemImage: "folder", action: onReveal)
            }
            if let onRemove {
                Divider()
                Button(role: .destructive, action: onRemove) {
                    Label("Remove from Library", systemImage: "trash")
                }
            }
        }
    }


    // MARK: - Source

    // MARK: - Artwork

}

#Preview("Library") {
    @Previewable @State var selectedTrack: LocalTrack?
    let scene = MSRUPreviewData.makeScene(section: .library)
    LibraryView(feature: scene.libraryFeature, localStore: scene.application.localLibrary,
                playback: scene.application.playback, selectedLocalTrack: $selectedTrack, onAddMusic: {})
        .frame(width: 900, height: 650)
}

#Preview("Library · Compact") {
    let scene = MSRUPreviewData.makeScene(section: .library)
    LibraryView(feature: scene.libraryFeature, localStore: scene.application.localLibrary,
        playback: scene.application.playback, selectedLocalTrack: .constant(nil), onAddMusic: {})
        .frame(width: 360, height: 640)
}

#Preview("Library Cards") {
    let local = MSRUPreviewData.localTracks[0]
    HStack(spacing: 16) {
        LibraryView.LibraryLocalTrackCardItemView(
            track: local, isSelected: false, isPlaying: false,
            onSelect: {}, onPlay: {}, onPlayNext: {}, onEnqueue: {},
            onReveal: {}, onRemove: {}
        )
    }
    .frame(width: 400)
    .padding()
}
