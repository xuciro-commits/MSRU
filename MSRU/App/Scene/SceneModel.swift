//
//  SceneModel.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation
import MusicLibrary

// MARK: - Scene Restoration Snapshot

nonisolated struct SceneRestorationSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let sceneID: SceneID
    var section: SceneSection
    var isQueuePresented: Bool

    init(
        version: Int = Self.currentVersion,
        sceneID: SceneID,
        section: SceneSection,
        isQueuePresented: Bool
    ) {
        self.version = version
        self.sceneID = sceneID
        self.section = section
        self.isQueuePresented = isQueuePresented
    }

    var isSupported: Bool {
        version == Self.currentVersion
    }
}

// MARK: - Scene Restoration Store

@MainActor
protocol SceneRestorationStore: AnyObject {
    func loadSnapshots() -> [SceneRestorationSnapshot]
    func save(_ snapshot: SceneRestorationSnapshot)
    func remove(sceneID: SceneID)
}

// MARK: - Application Scene Runtime Protocol

@MainActor
protocol ApplicationSceneRuntime: AnyObject {
    var id: SceneID { get }
    func send(_ command: SceneCommand)
}

// MARK: - Application Multi Scene Runtime Protocol

@MainActor
protocol ApplicationMultiSceneRuntime: AnyObject {
    @discardableResult
    func route(_ request: SceneRoutingRequest) -> SceneID?
    @discardableResult
    func openNewScene(route: SceneRoute?) -> SceneID
    @discardableResult
    func activateScene(_ sceneID: SceneID) -> Bool
}

// MARK: - Scene Model

@MainActor
@Observable
final class SceneModel: Identifiable, ApplicationSceneRuntime {
    let id: SceneID
    let application: ApplicationModel
    let navigation: SceneNavigation

    var selectedMusicContent: MusicContent?
    var selectedLocalTrack: LocalTrack?
    var selectedRadioStation: RadioStation?
    var selectedSourceFilter: String?
    var requestedAlbumID: String?
    var requestedArtistID: String?

    // MARK: - Feature Search Queries

    var librarySearchQuery: String = ""
    var albumsSearchQuery: String = ""
    var artistsSearchQuery: String = ""
    var playlistsSearchQuery: String = ""

    func navigateToSource(sourceID: String?, target: SceneSection) {
        guard !isClosed else { return }
        self.selectedSourceFilter = sourceID
        send(.navigate(.section(target)))
    }

    enum ContextPane: String, CaseIterable, Identifiable, Codable, Sendable {
        case inspector
        case queue
        case lyrics

        var id: String { rawValue }

        var title: String {
            switch self {
            case .inspector: return "Details"
            case .queue: return "Queue"
            case .lyrics: return "Lyrics"
            }
        }
    }

    var activeContextPane: ContextPane = .inspector
    var isQueuePresented: Bool
    var isNowPlayingPresented: Bool

    func select(localTrack: LocalTrack?) {
        guard !isClosed else { return }
        self.selectedLocalTrack = localTrack
        if localTrack != nil {
            self.selectedMusicContent = nil
            self.selectedRadioStation = nil
            self.activeContextPane = .inspector
            self.isQueuePresented = true
        }
    }

    func select(musicContent: MusicContent?) {
        guard !isClosed else { return }
        self.selectedMusicContent = musicContent
        if musicContent != nil {
            self.selectedLocalTrack = nil
            self.selectedRadioStation = nil
            self.activeContextPane = .inspector
            self.isQueuePresented = true
        }
    }

    func select(radioStation: RadioStation?) {
        guard !isClosed else { return }
        self.selectedRadioStation = radioStation
        if radioStation != nil {
            self.selectedLocalTrack = nil
            self.selectedMusicContent = nil
            self.activeContextPane = .inspector
            self.isQueuePresented = true
        }
    }

    func toggleContextPane(_ pane: ContextPane) {
        guard !isClosed else { return }
        if isQueuePresented && activeContextPane == pane {
            isQueuePresented = false
        } else {
            activeContextPane = pane
            isQueuePresented = true
        }
    }

    func toggleQueue() {
        toggleContextPane(.queue)
    }

    func toggleNowPlaying() {
        guard !isClosed else { return }
        isNowPlayingPresented.toggle()
    }

    func setNowPlaying(presented: Bool) {
        guard !isClosed else { return }
        isNowPlayingPresented = presented
    }

    // MARK: - Features

    let browse: FeatureHost<BrowseFeature>
    let libraryFeature: FeatureHost<LibraryFeature>
    let radioFeature: FeatureHost<RadioFeature>

    private(set) var isClosed = false

    func close() {
        guard !isClosed else { return }
        isClosed = true
        isNowPlayingPresented = false
        browse.stop()
        libraryFeature.stop()
        radioFeature.stop()
    }

    // MARK: - Init

    init(
        id: SceneID = SceneID(),
        application: ApplicationModel,
        section: SceneSection = .listenNow,
        isQueuePresented: Bool = true,
        isNowPlayingPresented: Bool = false
    ) {
        self.id = id
        self.application = application
        self.navigation = SceneNavigation(section: section)
        self.isQueuePresented = isQueuePresented
        self.isNowPlayingPresented = isNowPlayingPresented

        self.browse = withDependencies(application.dependencies) {
            FeatureHost<BrowseFeature>(service: BrowseFeature.Service())
        }
        self.libraryFeature = withDependencies(application.dependencies) {
            FeatureHost<LibraryFeature>(service: LibraryFeature.Service())
        }
        self.radioFeature = withDependencies(application.dependencies) {
            FeatureHost<RadioFeature>(service: RadioFeature.Service())
        }
    }

    convenience init?(
        application: ApplicationModel,
        restoration: SceneRestorationSnapshot
    ) {
        guard restoration.isSupported else { return nil }
        self.init(
            id: restoration.sceneID,
            application: application,
            section: restoration.section,
            isQueuePresented: restoration.isQueuePresented
        )
    }

    // MARK: - Command Routing

    func send(_ command: SceneCommand) {
        guard !isClosed else { return }
        switch command {
        case .navigate(let route):
            navigation.navigate(to: route)
        }
    }

    // MARK: - Restoration

    func restorationSnapshot() -> SceneRestorationSnapshot {
        SceneRestorationSnapshot(
            sceneID: id,
            section: navigation.section,
            isQueuePresented: isQueuePresented
        )
    }
}
