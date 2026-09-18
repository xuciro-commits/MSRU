//
//  SceneModel.swift
//  MSRU
//

import Foundation
import Observation


// MARK: - Scene Scope

/*
 一个 SceneModel 对应一个 Window / Scene。

 多窗口时：

 ApplicationModel
 ├── SceneModel A
 ├── SceneModel B
 └── SceneModel C

 三个 Scene 共享：

 - LibraryStore
 - PlaybackController
 - Catalog
 - Provider registry
 - Dependencies

 但拥有独立：

 - Navigation / selection
 - presentation
 - Feature State
 - Feature Tasks
 */

@MainActor
@Observable
final class SceneModel:
    Identifiable {

    // MARK: - Identity

    let id:
        UUID


    // MARK: - Application

    let application:
        ApplicationModel


    // MARK: - Navigation

    var selectedSection:
        SidebarSection? =
            .listenNow


    // MARK: - Selection

    var selectedMusicContent:
        MusicContent?


    var selectedLocalTrack:
        LocalTrack?


    // MARK: - Presentation

    var isQueuePresented =
        true


    // MARK: - Features

    let browse:
        FeatureHost<BrowseFeature>


    let libraryFeature:
        FeatureHost<LibraryFeature>


    // MARK: - Init

    init(
        id:
            UUID = UUID(),
        application:
            ApplicationModel
    ) {

        self.id =
            id


        self.application =
            application


        /*
         每个 Scene 拥有自己的 FeatureHost。

         所以：

         Browse query / loading / task
         Library pending-removal state

         都不会跨 Window 相互污染。

         Service 依赖的 Library / Playback
         仍然来自共享的 Application scope。
         */

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
    }
}
