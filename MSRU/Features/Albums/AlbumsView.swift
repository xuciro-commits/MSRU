//
//  AlbumsView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import SubsonicKit
import MusicDomain
import MusicLibrary
import MusicPlayback

struct AlbumsView: View {
    @Bindable var localStore: LocalLibraryStore
    @Bindable var playback: PlaybackController
    var subsonicServers: SubsonicServerStore? = nil
    let onSelectTrack: (LocalTrack) -> Void
    var onAddMusic: (() -> Void)? = nil

    enum AlbumSortField: String, CaseIterable, Identifiable {
        case title = "Title"
        case artist = "Artist"
        case year = "Year"

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .title: return "Title"
            case .artist: return "Artist"
            case .year: return "Year"
            }
        }
    }

    @State private var searchQuery: String = ""
    @State private var sortField: AlbumSortField = .title
    @State private var localPager: LocalAlbumPager?
    @State private var selectedAlbum: AlbumPresentationModel?
    @State private var selectedLocalTracks: [LocalTrack] = []
    @State private var albumPendingDelete: AlbumPresentationModel?
    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var selectedAlbumIDs: Set<String> = []
    @State private var isBatchDeleteConfirmationPresented: Bool = false
    @Binding var selectedSourceID: String?
    @Binding var requestedAlbumID: String?
    @State private var availableSources: [SourceFilterItem] = []
    @State private var remoteAlbums: [AlbumPresentationModel] = []
    @State private var isLoadingRemote: Bool = false
    @State private var remoteLoadError: String? = nil
    @State private var remoteOffset: Int = 0
    @State private var hasMoreRemote: Bool = true
    @State private var isLoadingMoreRemote: Bool = false
    @State private var remoteSearchResults: [AlbumPresentationModel] = []
    @State private var isSearchingRemote: Bool = false
    private let pageSize: Int = 50

    init(
        localStore: LocalLibraryStore,
        playback: PlaybackController,
        subsonicServers: SubsonicServerStore? = nil,
        selectedSourceID: Binding<String?> = .constant(nil),
        requestedAlbumID: Binding<String?> = .constant(nil),
        onSelectTrack: @escaping (LocalTrack) -> Void,
        onAddMusic: (() -> Void)? = nil
    ) {
        self.localStore = localStore
        self.playback = playback
        self.subsonicServers = subsonicServers
        self._selectedSourceID = selectedSourceID
        self._requestedAlbumID = requestedAlbumID
        self.onSelectTrack = onSelectTrack
        self.onAddMusic = onAddMusic
    }

    private var isRemoteSourceActive: Bool {
        guard let selectedSourceID else { return false }
        return !SourceID.isLocalSourceID(selectedSourceID)
    }

    private var filteredAlbums: [AlbumPresentationModel] {
        if isRemoteSourceActive {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty ? remoteAlbums : remoteSearchResults
        }
        return localPager?.albums ?? []
    }

    private func loadRemoteAlbums(sourceID: String, reset: Bool = true) async {
        guard !SourceID.isLocalSourceID(sourceID), let serversStore = subsonicServers else {
            remoteAlbums = []
            return
        }
        let cleanID = SourceID(serverKeyOrSourceID: sourceID)
        guard let client = serversStore.client(for: cleanID),
              let server = serversStore.server(for: cleanID) else {
            return
        }

        if reset {
            isLoadingRemote = true
            remoteOffset = 0
            hasMoreRemote = true
            remoteAlbums = []
        } else {
            guard hasMoreRemote, !isLoadingMoreRemote, !isLoadingRemote else { return }
            isLoadingMoreRemote = true
        }
        remoteLoadError = nil
        defer {
            isLoadingRemote = false
            isLoadingMoreRemote = false
        }

        let typeParam: String
        switch sortField {
        case .title: typeParam = "alphabeticalByName"
        case .artist: typeParam = "alphabeticalByArtist"
        case .year: typeParam = "byYear"
        }

        do {
            let dtos = try await client.albumList2(type: typeParam, size: pageSize, offset: remoteOffset)
            let mapped = dtos.map { dto -> AlbumPresentationModel in
                let coverArtURL = try? client.coverArtURL(id: dto.coverArt ?? dto.id)
                return AlbumPresentationModel(
                    id: "subsonic:\(cleanID.serverKey):\(dto.id)",
                    title: dto.effectiveTitle,
                    artist: dto.artist ?? "Unknown Artist",
                    year: dto.year,
                    artworkURL: coverArtURL,
                    artworkReference: coverArtURL?.absoluteString,
                    trackCount: dto.songCount ?? 0,
                    duration: TimeInterval(dto.duration ?? 0),
                    audioQualityBadge: nil,
                    sourceBadge: server.name,
                    versionCount: 1,
                    discs: []
                )
            }
            if reset {
                self.remoteAlbums = mapped
            } else {
                self.remoteAlbums.append(contentsOf: mapped)
            }
            self.remoteOffset += dtos.count
            if dtos.count < pageSize {
                self.hasMoreRemote = false
            }
        } catch is CancellationError {
            // Cancelled
        } catch {
            self.remoteLoadError = error.localizedDescription
            print("[AlbumsView] Failed to load remote albums: \(error)")
        }
    }

    private func searchRemoteAlbums(query: String, sourceID: String) async {
        guard !SourceID.isLocalSourceID(sourceID), let serversStore = subsonicServers else {
            remoteSearchResults = []
            return
        }
        let cleanID = SourceID(serverKeyOrSourceID: sourceID)
        guard let client = serversStore.client(for: cleanID),
              let server = serversStore.server(for: cleanID) else {
            return
        }

        isSearchingRemote = true
        defer { isSearchingRemote = false }

        do {
            let searchResult = try await client.search3(query: query, artistCount: 0, albumCount: 100, songCount: 0)
            let dtos = searchResult.album ?? []
            let mapped = dtos.map { dto -> AlbumPresentationModel in
                let coverArtURL = try? client.coverArtURL(id: dto.coverArt ?? dto.id)
                return AlbumPresentationModel(
                    id: "subsonic:\(cleanID.serverKey):\(dto.id)",
                    title: dto.effectiveTitle,
                    artist: dto.artist ?? "Unknown Artist",
                    year: dto.year,
                    artworkURL: coverArtURL,
                    artworkReference: coverArtURL?.absoluteString,
                    trackCount: dto.songCount ?? 0,
                    duration: TimeInterval(dto.duration ?? 0),
                    audioQualityBadge: nil,
                    sourceBadge: server.name,
                    versionCount: 1,
                    discs: []
                )
            }
            self.remoteSearchResults = mapped
        } catch is CancellationError {
            // Cancelled
        } catch {
            print("[AlbumsView] Failed to search remote albums: \(error)")
        }
    }

    var body: some View {
        Group {
            if let album = selectedAlbum {
                AlbumDetailView(
                    album: album,
                    localTracks: selectedLocalTracks,
                    subsonicServers: subsonicServers,
                    playback: playback,
                    onBack: { selectedAlbum = nil },
                    onSelectTrack: onSelectTrack,
                    onDeleteAlbum: album.id.hasPrefix("subsonic:") ? nil : {
                        albumPendingDelete = album
                        isDeleteConfirmationPresented = true
                    },
                    onFetchArtwork: album.id.hasPrefix("subsonic:") ? nil : { () -> Void in
                        Task {
                            await localStore.reidentifyAlbum(albumTitle: album.title, artist: album.artist)
                            if let updated = try? await localStore.findAlbum(id: album.id) {
                                selectedAlbum = updated
                            }
                        }
                    }
                )
            } else {
                mainAlbumsGrid
            }
        }
        .task(id: "\(selectedAlbum?.id ?? "")|\(localStore.revision)") {
            guard let album = selectedAlbum, !album.id.hasPrefix("subsonic:") else {
                selectedLocalTracks = []
                return
            }
            let tracks = try? await localStore.fetchTracks(forReleaseIDs: [album.id])
            guard !Task.isCancelled else { return }
            selectedLocalTracks = tracks ?? []
        }
        .task(id: requestedAlbumID) {
            if let requestedAlbumID,
               let album = try? await localStore.findAlbum(id: requestedAlbumID) {
                selectedAlbum = album
                self.requestedAlbumID = nil
            }
        }
        .task(id: "\(selectedSourceID ?? "")|\(searchQuery)|\(sortField.rawValue)|\(localStore.revision)") {
            guard !isRemoteSourceActive else { return }
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
            }
            let pager = localPager ?? localStore.makeAlbumPager()
            localPager = pager
            let sort: LocalSummaryRepository.AlbumSort
            switch sortField {
            case .title: sort = .title
            case .artist: sort = .artist
            case .year: sort = .year
            }
            await pager.reset(query: query, sort: sort)
        }
        .task(id: "\(selectedSourceID ?? "")-\(sortField.rawValue)") {
            if isRemoteSourceActive, let sourceID = selectedSourceID {
                await loadRemoteAlbums(sourceID: sourceID, reset: true)
            }
        }
        .task(id: "\(selectedSourceID ?? "")-\(searchQuery)") {
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if isRemoteSourceActive, let sourceID = selectedSourceID {
                if trimmed.isEmpty {
                    remoteSearchResults = []
                } else {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await searchRemoteAlbums(query: trimmed, sourceID: sourceID)
                }
            }
        }
        .confirmationDialog(
            "Delete album \"\(albumPendingDelete?.title ?? "")\"?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete album and all songs", role: .destructive) {
                if let toDelete = albumPendingDelete {
                    Task {
                        await localStore.deleteAlbum(title: toDelete.title, artist: toDelete.artist)
                        if selectedAlbum?.id == toDelete.id {
                            selectedAlbum = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all songs under this album from the local library.")
        }
        .confirmationDialog(
            "Delete \(selectedAlbumIDs.count) albums?",
            isPresented: $isBatchDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete \(selectedAlbumIDs.count) albums and all songs", role: .destructive) {
                let toDelete = filteredAlbums.filter { selectedAlbumIDs.contains($0.id) }
                Task {
                    for album in toDelete {
                        await localStore.deleteAlbum(title: album.title, artist: album.artist)
                    }
                    selectedAlbumIDs.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all songs under the selected albums from the local library.")
        }
        .task {
            availableSources = (try? await LibraryQueryEngine.shared.fetchAvailableSources(for: "release")) ?? []
            if let servers = subsonicServers?.servers {
                for server in servers {
                    let sourceID = server.id.rawValue
                    if !availableSources.contains(where: { $0.sourceID == sourceID }) {
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
    }

    @ViewBuilder
    private var mainAlbumsGrid: some View {
        if localStore.isLoading || (!isRemoteSourceActive && (localPager == nil || localPager?.isLoading == true && localPager?.albums.isEmpty == true)) || (isLoadingRemote && remoteAlbums.isEmpty) || isSearchingRemote {
            VStack(spacing: 0) {
                header
                Divider()
                ProgressView(isSearchingRemote ? "正在远程检索专辑..." : (isLoadingRemote ? "正在从远程媒体服务加载专辑..." : ""))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if filteredAlbums.isEmpty {
            VStack(spacing: 0) {
                header
                Divider()
                if isRemoteSourceActive {
                    ContentUnavailableView(
                        searchQuery.isEmpty ? "未发现远程专辑" : "未找到匹配的远程专辑",
                        systemImage: "opticaldisc",
                        description: Text(searchQuery.isEmpty ? (remoteLoadError ?? "远程媒体库中暂未发现专辑，或请检查服务器连接状态。") : "在远程媒体库中未找到与 \"\(searchQuery)\" 相关的专辑。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if let error = localPager?.errorMessage {
                        VStack {
                            ContentUnavailableView("无法加载专辑", systemImage: "exclamationmark.triangle",
                                                   description: Text(error))
                            Button("重试") { Task { await localPager?.retry() } }
                        }
                    } else {
                        emptyState
                    }
                }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Divider()

                    MarqueeSelectionContainer(selectedIDs: $selectedAlbumIDs) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180, maximum: 200), spacing: 20)],
                            spacing: 24
                        ) {
                            ForEach(filteredAlbums) { album in
                                AlbumCardView(
                                    album: album,
                                    isSelected: selectedAlbumIDs.contains(album.id),
                                    onSelect: {
                                        SelectionHelper.handleTap(
                                            for: album.id,
                                            selectedIDs: $selectedAlbumIDs,
                                            allIDs: filteredAlbums.map(\.id)
                                        )
                                    },
                                    onPlay: {
                                        playAlbum(album)
                                    }
                                ) {
                                    ArtworkThumbnailView(
                                        reference: album.artworkReference,
                                        thumbnailPixelSize: CGSize(width: 240, height: 240),
                                        placeholderSystemImage: "square.stack",
                                        cornerRadius: 10
                                    )
                                }
                                .marqueeItem(id: album.id)
                                .frame(height: 240)
                                .simultaneousGesture(
                                    TapGesture(count: 2).onEnded {
                                        selectedAlbum = album
                                    }
                                )
                                .contextMenu {
                                    Button("Open Album") { selectedAlbum = album }
                                    Button("Play Album") { playAlbum(album) }
                                    Button {
                                        Task {
                                            await localStore.reidentifyAlbum(albumTitle: album.title, artist: album.artist)
                                        }
                                    } label: {
                                        Label("Fetch Album Artwork", systemImage: "arrow.clockwise")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        albumPendingDelete = album
                                        isDeleteConfirmationPresented = true
                                    } label: {
                                        Label("Delete Album (Cascade)", systemImage: "trash")
                                    }
                                }
                                .onAppear {
                                    if isRemoteSourceActive && album.id == remoteAlbums.last?.id && hasMoreRemote && !isLoadingMoreRemote && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        if let sourceID = selectedSourceID {
                                            Task {
                                                await loadRemoteAlbums(sourceID: sourceID, reset: false)
                                            }
                                        }
                                    } else if !isRemoteSourceActive,
                                              filteredAlbums.suffix(12).contains(where: { $0.id == album.id }),
                                              localPager?.hasMore == true {
                                        Task { await localPager?.loadMore() }
                                    }
                                }
                            }
                        }
                    }

                    if isLoadingMoreRemote || (!isRemoteSourceActive && localPager?.isLoading == true) {
                        HStack(spacing: 8) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在加载更多专辑...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    if !isRemoteSourceActive, let error = localPager?.errorMessage {
                        HStack {
                            Text(error).foregroundStyle(.secondary)
                            Button("重试") { Task { await localPager?.retry() } }
                        }
                    }
                }
                .padding(24)
            }
            .hideScrollIndicatorsCompletely()
            .overlay(alignment: .bottom) {
                if selectedAlbumIDs.count > 1 {
                    floatingBatchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedAlbumIDs.count)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Albums")
                        .font(.largeTitle.bold())

                    Text(albumsSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let onAddMusic {
                    Button {
                        onAddMusic()
                    } label: {
                        Label("Add Music", systemImage: "plus")
                            .font(.callout.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                HStack(spacing: 10) {
                    if isSearchingRemote {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                    }

                    TextField(isRemoteSourceActive ? "搜索远程专辑…" : "Filter albums…", text: $searchQuery)
                        .textFieldStyle(.plain)

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 260)

                HStack {
                    Spacer()
                    Picker("Sort", selection: $sortField) {
                        ForEach(AlbumSortField.allCases) { field in
                            Text(LocalizedStringKey(field.rawValue)).tag(field)
                        }
                    }
                    .frame(width: 110)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if !availableSources.isEmpty {
                SourceFilterBarView(sources: availableSources, selectedSourceID: $selectedSourceID)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var albumsSubtitle: String {
        if isRemoteSourceActive {
            if isLoadingRemote && remoteAlbums.isEmpty {
                return String(localized: "正在从远程媒体服务加载…")
            }
            if isSearchingRemote {
                return String(localized: "正在检索远程专辑…")
            }
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                return "搜索结果：\(filteredAlbums.count) 张专辑"
            }
            let serverName = availableSources.first(where: { $0.sourceID == selectedSourceID })?.displayName ?? "远程媒体服务"
            return "\(serverName) • 按需在线浏览"
        } else {
            return "\(localPager?.totalCount ?? filteredAlbums.count) 张专辑"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("No albums found")
                .font(.headline)

            Text("Import music or adjust search terms to see albums.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func playAlbum(_ album: AlbumPresentationModel) {
        if album.id.hasPrefix("subsonic:"), let subsonicServers {
            let parts = album.id.split(separator: ":")
            if parts.count >= 3 {
                let serverID = LibrarySourceID(String(parts[1]))
                let remoteAlbumID = String(parts[2])
                if let client = subsonicServers.client(for: serverID) {
                    Task {
                        if let detailed = try? await client.album(id: remoteAlbumID),
                           let songs = detailed.song, !songs.isEmpty {
                            let items = songs.compactMap { song -> PlaybackItem? in
                                let streamURL = try? client.streamURL(id: song.id)
                                let coverArtURL = try? client.coverArtURL(id: song.coverArt ?? remoteAlbumID)
                                return PlaybackItem.subsonic(
                                    serverID: serverID,
                                    itemID: song.id,
                                    title: song.title,
                                    artist: song.artist ?? album.artist,
                                    album: album.title,
                                    streamURL: streamURL,
                                    coverArtURL: coverArtURL
                                )
                            }
                            if let first = items.first {
                                playback.play(first, context: items)
                            }
                        }
                    }
                }
            }
            return
        }

        Task {
            guard let matching = try? await localStore.fetchTracks(forReleaseIDs: [album.id]),
                  let first = matching.first else { return }
            playback.play(first, queue: matching)
        }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedAlbumIDs.count,
            title: "\(selectedAlbumIDs.count) albums",
            onDeselect: { selectedAlbumIDs.removeAll() }
        ) {
            Button {
                let selected = filteredAlbums.filter { selectedAlbumIDs.contains($0.id) }
                Task {
                    guard let tracks = try? await localStore.fetchTracks(forReleaseIDs: Set(selected.map(\.id))),
                          let first = tracks.first else { return }
                    playback.toggle(track: first, queue: tracks)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredAlbums.filter { selectedAlbumIDs.contains($0.id) }
                Task {
                    guard let tracks = try? await localStore.fetchTracks(forReleaseIDs: Set(selected.map(\.id))) else { return }
                    for track in tracks { playback.addToQueue(track) }
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                let selected = filteredAlbums.filter { selectedAlbumIDs.contains($0.id) }
                Task {
                    for a in selected {
                        await localStore.reidentifyAlbum(albumTitle: a.title, artist: a.artist)
                    }
                }
            } label: {
                Label("Fetch Artwork", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                isBatchDeleteConfirmationPresented = true
            } label: {
                Label("Delete Albums", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Feature

enum AlbumsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "albums",
                    group: "Library",
                    title: "Albums",
                    systemImage: "square.stack",
                    route: .section(.albums),
                    order: 110
                )
            ],
            routes: [
                RouteContribution(
                    id: "albums",
                    route: .section(.albums)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "albums",
                route: .section(.albums)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Albums"),
                        systemImage: "square.stack"
                    )
                ) { _ in
                    AlbumsView(
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        subsonicServers: scene.application.subsonicServers,
                        selectedSourceID: Binding(
                            get: { scene.selectedSourceFilter },
                            set: { scene.selectedSourceFilter = $0 }
                        ),
                        requestedAlbumID: Binding(
                            get: { scene.requestedAlbumID },
                            set: { scene.requestedAlbumID = $0 }
                        ),
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        },
                        onAddMusic: {
                            scene.send(.navigate(.section(.addMusic)))
                        }
                    )
                }
            }
        ]
    }
}

// MARK: - Preview

#Preview("Albums View") {
    let scene = MSRUPreviewData.makeScene(section: .albums)
    AlbumsView(
        localStore: scene.application.localLibrary,
        playback: scene.application.playback,
        onSelectTrack: { _ in }
    )
    .frame(width: 800, height: 600)
}
