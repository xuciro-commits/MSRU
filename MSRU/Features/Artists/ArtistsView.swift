//
//  ArtistsView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import SubsonicKit
import MusicDomain
import MusicLibrary
import MusicPlayback

struct ArtistsView: View {
    @Bindable var localStore: LocalLibraryStore
    @Bindable var playback: PlaybackController
    var subsonicServers: SubsonicServerStore? = nil
    @Binding var selectedSourceID: String?
    @Binding var requestedArtistID: String?
    let onSelectTrack: (LocalTrack) -> Void
    var onAddMusic: (() -> Void)? = nil

    @Binding private var searchQuery: String
    @State private var localPager: LocalArtistPager?
    @State private var selectedArtist: ArtistPresentationModel?
    @State private var selectedAlbum: AlbumPresentationModel?
    @State private var selectedArtistTracks: [LocalTrack] = []
    @State private var selectedAlbumTracks: [LocalTrack] = []
    @State private var artistPendingDelete: ArtistPresentationModel?
    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var selectedArtistIDs: Set<String> = []
    @State private var isBatchDeleteConfirmationPresented: Bool = false

    @State private var availableSources: [SourceFilterItem] = []
    @State private var remoteArtists: [ArtistPresentationModel] = []
    @State private var seenArtistKeys: Set<String> = []
    @State private var remoteOffset: Int = 0
    @State private var hasMoreRemote: Bool = true
    @State private var isLoadingRemote: Bool = false
    @State private var isLoadingMoreRemote: Bool = false
    @State private var remoteSearchResults: [ArtistPresentationModel] = []
    @State private var isSearchingRemote: Bool = false
    @State private var remoteLoadError: String? = nil
    private let pageSize: Int = 50

    init(
        localStore: LocalLibraryStore,
        playback: PlaybackController,
        subsonicServers: SubsonicServerStore? = nil,
        searchQuery: Binding<String> = .constant(""),
        selectedSourceID: Binding<String?> = .constant(nil),
        requestedArtistID: Binding<String?> = .constant(nil),
        onSelectTrack: @escaping (LocalTrack) -> Void,
        onAddMusic: (() -> Void)? = nil
    ) {
        self.localStore = localStore
        self.playback = playback
        self.subsonicServers = subsonicServers
        self._searchQuery = searchQuery
        self._selectedSourceID = selectedSourceID
        self._requestedArtistID = requestedArtistID
        self.onSelectTrack = onSelectTrack
        self.onAddMusic = onAddMusic
    }

    private var isRemoteSourceActive: Bool {
        SourceScope(sourceID: selectedSourceID).isRemote
    }

    private var filteredArtists: [ArtistPresentationModel] {
        if isRemoteSourceActive {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty ? remoteArtists : remoteSearchResults
        }
        return localPager?.artists ?? []
    }

    private func loadRemoteArtists(sourceID: String, reset: Bool = true) async {
        guard !SourceID.isLocalSourceID(sourceID), let serversStore = subsonicServers else {
            remoteArtists = []
            seenArtistKeys = []
            return
        }
        let cleanID = SourceID(serverKeyOrSourceID: sourceID)
        guard let client = serversStore.client(for: cleanID) else {
            return
        }

        if reset {
            isLoadingRemote = true
            remoteOffset = 0
            hasMoreRemote = true
            remoteArtists = []
            seenArtistKeys = []
        } else {
            guard hasMoreRemote, !isLoadingMoreRemote, !isLoadingRemote else { return }
            isLoadingMoreRemote = true
        }
        remoteLoadError = nil
        defer {
            isLoadingRemote = false
            isLoadingMoreRemote = false
        }

        do {
            var newArtists: [ArtistPresentationModel] = []
            var currentOffset = remoteOffset
            let batchAlbumSize = 60

            // Pull albums in small 60-album chunks and extract unique artists without full index download freeze
            while newArtists.count < (reset ? 30 : 20) && hasMoreRemote {
                let albumDTOs = try await client.albumList2(type: "alphabeticalByArtist", size: batchAlbumSize, offset: currentOffset)
                if albumDTOs.isEmpty {
                    hasMoreRemote = false
                    break
                }
                currentOffset += albumDTOs.count

                for album in albumDTOs {
                    guard let artistName = album.artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artistName.isEmpty else {
                        continue
                    }
                    let artistID = album.artistId ?? artistName
                    let dedupeKey = "\(cleanID.serverKey):\(artistID)"
                    if !seenArtistKeys.contains(dedupeKey) {
                        seenArtistKeys.insert(dedupeKey)
                        let coverArtURL = try? client.coverArtURL(id: album.coverArt ?? album.id)
                        newArtists.append(ArtistPresentationModel(
                            id: "subsonic:\(cleanID.serverKey):\(artistID)",
                            name: artistName,
                            aliases: [],
                            albumCount: 1,
                            trackCount: 0,
                            artworkURL: coverArtURL,
                            artworkReference: coverArtURL?.absoluteString
                        ))
                    }
                }

                if albumDTOs.count < batchAlbumSize {
                    hasMoreRemote = false
                    break
                }
            }

            self.remoteOffset = currentOffset
            if reset {
                self.remoteArtists = newArtists
            } else {
                self.remoteArtists.append(contentsOf: newArtists)
            }
        } catch is CancellationError {
            // Cancelled
        } catch {
            self.remoteLoadError = error.localizedDescription
            print("[ArtistsView] Failed to load remote artists: \(error)")
        }
    }

    private func searchRemoteArtists(query: String, sourceID: String) async {
        guard !SourceID.isLocalSourceID(sourceID), let serversStore = subsonicServers else {
            remoteSearchResults = []
            return
        }
        let cleanID = SourceID(serverKeyOrSourceID: sourceID)
        guard let client = serversStore.client(for: cleanID) else {
            return
        }

        isSearchingRemote = true
        defer { isSearchingRemote = false }

        do {
            let searchResult = try await client.search3(query: query, artistCount: 50, albumCount: 0, songCount: 0)
            let dtos = searchResult.artist ?? []
            let mapped = dtos.map { dto -> ArtistPresentationModel in
                let coverArtURL = try? client.coverArtURL(id: dto.coverArt ?? dto.id)
                return ArtistPresentationModel(
                    id: "subsonic:\(cleanID.serverKey):\(dto.id)",
                    name: dto.name,
                    aliases: [],
                    albumCount: dto.albumCount ?? 0,
                    trackCount: 0,
                    artworkURL: coverArtURL,
                    artworkReference: coverArtURL?.absoluteString
                )
            }
            self.remoteSearchResults = mapped
        } catch is CancellationError {
            // Cancelled
        } catch {
            print("[ArtistsView] Failed to search remote artists: \(error)")
        }
    }

    var body: some View {
        Group {
            if let album = selectedAlbum {
                AlbumDetailView(
                    album: album,
                    localTracks: selectedAlbumTracks,
                    subsonicServers: subsonicServers,
                    playback: playback,
                    onBack: { selectedAlbum = nil },
                    onSelectTrack: onSelectTrack,
                    onDeleteAlbum: album.id.hasPrefix("subsonic:") ? nil : {
                        selectedAlbum = nil
                    }
                )
            } else if let artist = selectedArtist {
                ArtistDetailView(
                    artist: artist,
                    tracks: selectedArtistTracks,
                    subsonicServers: subsonicServers,
                    playback: playback,
                    onBack: { selectedArtist = nil },
                    onSelectTrack: onSelectTrack,
                    onSelectAlbum: { album in
                        selectedAlbum = album
                    },
                    onDeleteArtist: artist.id.hasPrefix("subsonic:") ? nil : {
                        artistPendingDelete = artist
                        isDeleteConfirmationPresented = true
                    }
                )
            } else {
                mainArtistsGrid
            }
        }
        .task(id: "\(selectedArtist?.id ?? "")|\(localStore.revision)") {
            guard let artist = selectedArtist, !artist.id.hasPrefix("subsonic:") else {
                selectedArtistTracks = []
                return
            }
            let tracks = try? await localStore.fetchTracks(forArtistIDs: [artist.id])
            guard !Task.isCancelled else { return }
            selectedArtistTracks = tracks ?? []
        }
        .task(id: "\(selectedAlbum?.id ?? "")|\(localStore.revision)") {
            guard let album = selectedAlbum, !album.id.hasPrefix("subsonic:") else {
                selectedAlbumTracks = []
                return
            }
            let tracks = try? await localStore.fetchTracks(forReleaseIDs: [album.id])
            guard !Task.isCancelled else { return }
            selectedAlbumTracks = tracks ?? []
        }
        .task(id: requestedArtistID) {
            if let requestedArtistID,
               let artist = try? await localStore.findArtist(id: requestedArtistID) {
                selectedArtist = artist
                self.requestedArtistID = nil
            }
        }
        .task(id: selectedSourceID) {
            if isRemoteSourceActive, let sourceID = selectedSourceID {
                await loadRemoteArtists(sourceID: sourceID, reset: true)
            }
        }
        .task(id: "\(selectedSourceID ?? "")|\(searchQuery)") {
            guard !isRemoteSourceActive else { return }
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
            }
            let pager = localPager ?? localStore.makeArtistPager()
            localPager = pager
            await pager.reset(query: query, sourceFilter: selectedSourceID)
        }
        .onChange(of: localStore.revision) { _, _ in
            guard !isRemoteSourceActive else { return }
            guard let pager = localPager else { return }
            Task {
                await pager.reload(preserveCount: true)
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
                    await searchRemoteArtists(query: trimmed, sourceID: sourceID)
                }
            }
        }
        .task {
            let servers = subsonicServers?.servers.map { ($0.id.rawValue, $0.name) } ?? []
            availableSources = (try? await LibraryQueryEngine.shared.fetchAvailableSources(for: "artist", additionalRemoteServers: servers)) ?? []
        }
        .confirmationDialog(
            "Delete artist \"\(artistPendingDelete?.name ?? "")\"?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete artist and all content", role: .destructive) {
                if let toDelete = artistPendingDelete {
                    Task {
                        await localStore.deleteArtist(name: toDelete.name)
                        if selectedArtist?.id == toDelete.id {
                            selectedArtist = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all albums and songs of this artist from the local library.")
        }
        .confirmationDialog(
            "Delete \(selectedArtistIDs.count) artists?",
            isPresented: $isBatchDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete \(selectedArtistIDs.count) artists and all content", role: .destructive) {
                let toDelete = filteredArtists.filter { selectedArtistIDs.contains($0.id) }
                Task {
                    for artist in toDelete {
                        await localStore.deleteArtist(name: artist.name)
                    }
                    selectedArtistIDs.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all albums and songs of the selected artists from the local library.")
        }
    }

    @ViewBuilder
    private var mainArtistsGrid: some View {
        if localStore.isLoading || (!isRemoteSourceActive && (localPager == nil || localPager?.isLoading == true && localPager?.artists.isEmpty == true)) || (isLoadingRemote && remoteArtists.isEmpty) || isSearchingRemote {
            VStack(spacing: 0) {
                header
                Divider()
                ProgressView(isSearchingRemote ? "正在远程检索艺术家..." : (isLoadingRemote ? "正在从远程媒体服务加载艺术家..." : ""))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if filteredArtists.isEmpty {
            VStack(spacing: 0) {
                header
                Divider()
                if isRemoteSourceActive {
                    ContentUnavailableView(
                        searchQuery.isEmpty ? "未发现远程艺术家" : "未找到匹配的远程艺术家",
                        systemImage: "music.mic",
                        description: Text(searchQuery.isEmpty ? (remoteLoadError ?? "远程媒体库中暂未发现艺术家，或请检查服务器连接状态。") : "在远程媒体库中未找到与 \"\(searchQuery)\" 相关的艺术家。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if let error = localPager?.errorMessage {
                        VStack {
                            ContentUnavailableView("无法加载艺术家", systemImage: "exclamationmark.triangle",
                                                   description: Text(error))
                            Button("Retry") { Task { await localPager?.retry() } }
                        }
                    } else {
                        emptyState
                    }
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    Divider()

                    MarqueeSelectionContainer(selectedIDs: $selectedArtistIDs) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 24)],
                            spacing: 28
                        ) {
                            ForEach(filteredArtists) { artist in
                                ArtistAvatarView(
                                    artist: artist,
                                    isSelected: selectedArtistIDs.contains(artist.id),
                                    onSelect: {
                                        SelectionHelper.handleTap(
                                            for: artist.id,
                                            selectedIDs: $selectedArtistIDs,
                                            allIDs: filteredArtists.map(\.id)
                                        )
                                    }
                                ) {
                                    ArtworkThumbnailView(
                                        reference: artist.artworkReference,
                                        thumbnailPixelSize: CGSize(width: 240, height: 240),
                                        placeholderSystemImage: "music.mic",
                                        isCircular: true
                                    )
                                }
                                .marqueeItem(id: artist.id)
                                .simultaneousGesture(
                                    TapGesture(count: 2).onEnded {
                                        selectedArtist = artist
                                    }
                                )
                                .contextMenu {
                                    Button("Open Artist") { selectedArtist = artist }
                                    Button("Play Artist") { playArtist(artist) }
                                    if !artist.id.hasPrefix("subsonic:") {
                                        Divider()
                                        Button(role: .destructive) {
                                            artistPendingDelete = artist
                                            isDeleteConfirmationPresented = true
                                        } label: {
                                            Label("Delete Artist (Cascade)", systemImage: "trash")
                                        }
                                    }
                                }
                                .onAppear {
                                    if isRemoteSourceActive && artist.id == remoteArtists.last?.id && hasMoreRemote && !isLoadingMoreRemote && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        if let sourceID = selectedSourceID {
                                            Task {
                                                await loadRemoteArtists(sourceID: sourceID, reset: false)
                                            }
                                        }
                                    } else if !isRemoteSourceActive,
                                              filteredArtists.suffix(12).contains(where: { $0.id == artist.id }),
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
                            Text("正在加载更多艺术家...")
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
                .padding(28)
            }
            .hideScrollIndicatorsCompletely()
            .overlay(alignment: .bottom) {
                if selectedArtistIDs.count > 1 {
                    floatingBatchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedArtistIDs.count)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artists")
                        .font(.largeTitle.bold())

                    Text(artistsSubtitle)
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

                HStack {
                    Spacer()
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

    private var artistsSubtitle: String {
        if isRemoteSourceActive {
            if isLoadingRemote && remoteArtists.isEmpty {
                return String(localized: "正在从远程媒体服务加载…")
            }
            if isSearchingRemote {
                return String(localized: "正在检索远程艺术家…")
            }
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                return "搜索结果：\(filteredArtists.count) 位艺术家"
            }
            let serverName = availableSources.first(where: { $0.sourceID == selectedSourceID })?.displayName ?? "远程媒体服务"
            return "\(serverName) • 按需在线浏览"
        } else {
            return "\(localPager?.totalCount ?? filteredArtists.count) 位艺术家"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.mic")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("No artists found")
                .font(.headline)

            Text("Imported artists will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func playArtist(_ artist: ArtistPresentationModel) {
        if artist.id.hasPrefix("subsonic:"), let subsonicServers {
            let parts = artist.id.split(separator: ":")
            if parts.count >= 3 {
                let serverID = LibrarySourceID(String(parts[1]))
                let remoteArtistID = String(parts[2])
                if let client = subsonicServers.client(for: serverID) {
                    Task {
                        if let artistDTO = try? await client.artist(id: remoteArtistID),
                           let albums = artistDTO.album, !albums.isEmpty {
                            for album in albums {
                                if let detailed = try? await client.album(id: album.id),
                                   let songs = detailed.song, !songs.isEmpty {
                                    let items = songs.compactMap { song -> PlaybackItem? in
                                        let streamURL = try? client.streamURL(id: song.id)
                                        let coverArtURL = try? client.coverArtURL(id: song.coverArt ?? album.id)
                                        return PlaybackItem.subsonic(
                                            serverID: serverID,
                                            itemID: song.id,
                                            title: song.title,
                                            artist: song.artist ?? artist.name,
                                            album: album.title,
                                            streamURL: streamURL,
                                            coverArtURL: coverArtURL
                                        )
                                    }
                                    if let first = items.first {
                                        playback.play(first, context: items)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return
        }

        Task {
            guard let matching = try? await localStore.fetchTracks(forArtistIDs: [artist.id]),
                  let first = matching.first else { return }
            playback.toggle(track: first, queue: matching)
        }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedArtistIDs.count,
            title: "\(selectedArtistIDs.count) artists",
            onDeselect: { selectedArtistIDs.removeAll() }
        ) {
            Button {
                let selected = filteredArtists.filter { selectedArtistIDs.contains($0.id) }
                Task {
                    guard let tracks = try? await localStore.fetchTracks(forArtistIDs: Set(selected.map(\.id))),
                          let first = tracks.first else { return }
                    playback.toggle(track: first, queue: tracks)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = filteredArtists.filter { selectedArtistIDs.contains($0.id) }
                Task {
                    guard let tracks = try? await localStore.fetchTracks(forArtistIDs: Set(selected.map(\.id))) else { return }
                    for track in tracks { playback.addToQueue(track) }
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                isBatchDeleteConfirmationPresented = true
            } label: {
                Label("Delete Artists", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Feature

enum ArtistsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "artists",
                    group: "Library",
                    title: "Artists",
                    systemImage: "music.mic",
                    route: .section(.artists),
                    order: 120
                )
            ],
            routes: [
                RouteContribution(
                    id: "artists",
                    route: .section(.artists)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "artists",
                route: .section(.artists)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Artists"),
                        systemImage: "music.mic"
                    ),
                    toolbar: artistsToolbar
                ) { _ in
                    ArtistsView(
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        subsonicServers: scene.application.subsonicServers,
                        searchQuery: Binding(
                            get: { scene.artistsSearchQuery },
                            set: { scene.artistsSearchQuery = $0 }
                        ),
                        selectedSourceID: Binding(
                            get: { scene.selectedSourceFilter },
                            set: { scene.selectedSourceFilter = $0 }
                        ),
                        requestedArtistID: Binding(
                            get: { scene.requestedArtistID },
                            set: { scene.requestedArtistID = $0 }
                        ),
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        },
                        onAddMusic: {
                            scene.send(.navigate(.section(.sources)))
                        }
                    )
                }
            }
        ]
    }

    // MARK: - Workspace Toolbar

    private static var artistsToolbar: ToolbarPresentation<SceneModel> {
        ToolbarPresentation(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "artists.search",
                        prompt: String(localized: "Filter artists…"),
                        text: { scene in
                            scene.artistsSearchQuery
                        },
                        update: { scene, value in
                            scene.artistsSearchQuery = value
                        }
                    )
                )
            ]
        )
    }
}

// MARK: - Preview

#Preview("Artists View") {
    let scene = MSRUPreviewData.makeScene(section: .artists)
    ArtistsView(
        localStore: scene.application.localLibrary,
        playback: scene.application.playback,
        onSelectTrack: { _ in }
    )
    .frame(width: 800, height: 600)
}
