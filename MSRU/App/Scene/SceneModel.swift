//
//  SceneModel.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation


// MARK: - Scene Scope

/*
 一个 SceneModel 对应一个 Window / Scene。

 Application Scope 负责共享资源。

 Scene Scope 负责：

 - Identity
 - Command Routing
 - Navigation
 - Selection
 - Presentation
 - Feature Runtime
 - Restoration Snapshot

 外部语义 Intent
 统一通过 send(_:) 进入 Scene。
 */

@MainActor
@Observable
final class SceneModel:
    Identifiable {

    // MARK: - Identity

    let id:
        SceneID


    // MARK: - Application

    let application:
        ApplicationModel


    // MARK: - Navigation

    let navigation:
        SceneNavigation


    // MARK: - Selection

    /*
     Selection != Navigation。

     当前 MusicContent / LocalTrack
     还没有对应真实 detail route。

     所以它们暂时仍是 runtime selection，
     不进入 SceneRoute。
     */

    var selectedMusicContent:
        MusicContent?


    var selectedLocalTrack:
        LocalTrack?


    var selectedLibraryTrack:
        LibraryTrack?


    var selectedRadioStation:
        RadioStation?


    // MARK: - Presentation

    enum ContextPane: String, CaseIterable, Identifiable, Codable, Sendable {
        case inspector
        case queue

        var id: String { rawValue }

        var title: String {
            switch self {
            case .inspector: return "Details"
            case .queue: return "Queue"
            }
        }
    }

    var activeContextPane: ContextPane = .inspector

    var isQueuePresented:
        Bool

    func select(localTrack: LocalTrack?) {
        guard !isClosed else { return }
        self.selectedLocalTrack = localTrack
        if localTrack != nil {
            self.selectedLibraryTrack = nil
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
            self.selectedLibraryTrack = nil
            self.selectedRadioStation = nil
            self.activeContextPane = .inspector
            self.isQueuePresented = true
        }
    }

    func select(libraryTrack: LibraryTrack?) {
        guard !isClosed else { return }
        self.selectedLibraryTrack = libraryTrack
        if libraryTrack != nil {
            self.selectedLocalTrack = nil
            self.selectedMusicContent = nil
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
            self.selectedLibraryTrack = nil
            self.selectedMusicContent = nil
            self.activeContextPane = .inspector
            self.isQueuePresented = true
        }
    }

    func toggleQueue() {
        guard !isClosed else { return }
        if isQueuePresented {
            if activeContextPane == .queue {
                isQueuePresented = false
            } else {
                activeContextPane = .queue
            }
        } else {
            activeContextPane = .queue
            isQueuePresented = true
        }
    }


    // MARK: - Features

    let browse:
        FeatureHost<BrowseFeature>


    let libraryFeature:
        FeatureHost<LibraryFeature>


    let radioFeature:
        FeatureHost<RadioFeature>


    private(set) var isClosed = false

    /// Closing is terminal; temporary scene inactivity must not call this.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        browse.stop()
        libraryFeature.stop()
        radioFeature.stop()
    }

    // MARK: - New Scene

    init(
        id:
            SceneID = SceneID(),
        application:
            ApplicationModel,
        section:
            SceneSection = .listenNow,
        isQueuePresented:
            Bool = true
    ) {

        self.id =
            id


        self.application =
            application


        self.navigation =
            SceneNavigation(
                section:
                    section
            )


        self.isQueuePresented =
            isQueuePresented


        self.browse =
            withDependencies(
                application.dependencies
            ) {

                FeatureHost<BrowseFeature>(
                    service:
                        BrowseFeature
                            .Service()
                )
            }


        self.libraryFeature =
            withDependencies(
                application.dependencies
            ) {

                FeatureHost<LibraryFeature>(
                    service:
                        LibraryFeature
                            .Service()
                )
            }


        self.radioFeature =
            withDependencies(
                application.dependencies
            ) {

                FeatureHost<RadioFeature>(
                    service:
                        RadioFeature
                            .Service()
                )
            }
    }


    // MARK: - Restored Scene

    convenience init?(
        application:
            ApplicationModel,
        restoration:
            SceneRestorationSnapshot
    ) {

        guard
            restoration.isSupported
        else {

            return nil
        }


        self.init(
            id:
                restoration.sceneID,
            application:
                application,
            section:
                restoration.section,
            isQueuePresented:
                restoration.isQueuePresented
        )
    }


    // MARK: - Command Routing

    /*
     Scene-level semantic intent
     统一从这里进入。

     Future callers:

     - Sidebar
     - Menu Commands
     - Deep Link
     - Handoff
     - Spotlight
     - Automation
     */

    func send(
        _ command:
            SceneCommand
    ) {

        guard !isClosed else { return }
        switch command {

        case .navigate(
            let route
        ):

            navigation
                .navigate(
                    to:
                        route
                )
        }
    }


    // MARK: - Restoration

    func restorationSnapshot()
        -> SceneRestorationSnapshot {

        SceneRestorationSnapshot(
            sceneID:
                id,
            section:
                navigation
                    .section,
            isQueuePresented:
                isQueuePresented
        )
    }
}
