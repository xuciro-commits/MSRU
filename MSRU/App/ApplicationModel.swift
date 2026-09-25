//
//  ApplicationModel.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation
import AppIntents
import MusicLibrary
import MusicPlayback

// MARK: - Application Scope

/*
 ApplicationModel 的生命周期等于整个 App。
 这里保存的是：
 - application-scoped stores
 - application-scoped services
 - dependency composition root
 - application lifecycle work

 它不保存：
 - 当前 Sidebar selection
 - 当前页面 selection
 - Window / Scene presentation
 - Feature-local runtime state
 那些全部属于 SceneModel。
 */

@MainActor
@Observable
final class ApplicationModel {

    // MARK: - Local Library
    let localLibrary: LocalLibraryStore
    private let spotlightIndexer = SpotlightIndexingService()

    // MARK: - Library
    let webLibrary: WebLibraryStore

    // MARK: - Apple Music
    let musicLibrary: AppleMusicLibraryStore

    // MARK: - Playback
    let playback: PlaybackController

    // MARK: - Providers
    let providerManager: ProviderManagerStore

    // MARK: - Radio
    let radioStore: RadioStore

    // MARK: - Playlists
    let playlistStore: PlaylistStore

    // MARK: - Watched Folders
    let watchedFolders: WatchedFolderStore

    // MARK: - Subsonic Servers & Coordinator
    let subsonicServers: SubsonicServerStore

    // MARK: - Language
    let languageSettings: LanguageSettings

    // MARK: - Dependencies
    let dependencies: DependencyValues

    // MARK: - Lifecycle
    private(set) var hasStarted = false
    private(set) var startupTask: Task<Void, Never>?
    private(set) var isTerminated = false
    private(set) var systemNowPlayingCoordinator: SystemNowPlayingCoordinator?

    // MARK: - Live Init
    convenience init() {
        self.init(
            localLibrary: LocalLibraryStore(),
            webLibrary: WebLibraryStore(),
            musicLibrary: AppleMusicLibraryStore(),
            playback: PlaybackController(),
            providerManager: ProviderManagerStore(),
            openverseSearch: OpenverseSearchClient.live,
            radioStore: RadioStore(),
            playlistStore: PlaylistStore(),
            languageSettings: LanguageSettings()
        )
    }

    // MARK: - Injected Init
    init(
        localLibrary: LocalLibraryStore,
        webLibrary: WebLibraryStore,
        musicLibrary: AppleMusicLibraryStore,
        playback: PlaybackController,
        providerManager: ProviderManagerStore,
        openverseSearch: OpenverseSearchClient,
        radioStore: RadioStore? = nil,
        playlistStore: PlaylistStore? = nil,
        languageSettings: LanguageSettings? = nil,
        watchedFolders: WatchedFolderStore? = nil,
        subsonicServers: SubsonicServerStore? = nil
    ) {
        self.localLibrary = localLibrary
        self.webLibrary = webLibrary
        self.musicLibrary = musicLibrary
        self.playback = playback
        self.providerManager = providerManager

        let resolvedRadioStore = radioStore ?? RadioStore()
        self.radioStore = resolvedRadioStore

        let resolvedPlaylistStore = playlistStore ?? PlaylistStore()
        self.playlistStore = resolvedPlaylistStore

        self.languageSettings = languageSettings ?? LanguageSettings()
        self.watchedFolders = watchedFolders ?? WatchedFolderStore(localStore: localLibrary)

        let resolvedSubsonicServers = subsonicServers ?? SubsonicServerStore()
        self.subsonicServers = resolvedSubsonicServers

        self.localLibrary.attachCascadeCollaborators(
            playlistStore: resolvedPlaylistStore,
            playbackController: playback
        )

        // MARK: Dependency Composition
        var dependencies = DependencyValues.live
        dependencies.webLibrary = webLibrary
        dependencies.playback = playback
        dependencies.openverseSearch = openverseSearch
        dependencies.radioStore = resolvedRadioStore
        dependencies.playlistStore = resolvedPlaylistStore
        self.dependencies = dependencies

        AppDependencyManager.shared.add(dependency: self)
    }

    // MARK: - Start
    func start() {
        guard !hasStarted, !isTerminated else { return }

        hasStarted = true
        MusicAppShortcuts.updateAppShortcutParameters()
        localLibrary.attachSpotlightIndexer(spotlightIndexer)

        let webLibrary = webLibrary
        let playlistStore = playlistStore

        let coordinator = SystemNowPlayingCoordinator(playback: playback)
        coordinator.activate()
        self.systemNowPlayingCoordinator = coordinator

        let localLibrary = localLibrary

        startupTask = Task {
            await localLibrary.loadIfNeeded()
            await webLibrary.load()
            await playlistStore.load()
            watchedFolders.startMonitoring()
        }
    }

    // MARK: - Terminate
    func terminate() {
        guard !isTerminated else { return }

        isTerminated = true
        systemNowPlayingCoordinator?.deactivate()
        systemNowPlayingCoordinator = nil
        watchedFolders.stopMonitoring()
        spotlightIndexer.cancel()
        startupTask?.cancel()
    }
}
