//
//  SceneModel.swift
//  MSRU
//

import Foundation
import Observation


// MARK: - Scene Scope

/*
 一个 SceneModel 对应一个 Window / Scene。

 Application Scope 负责共享资源。

 Scene Scope 负责：

 - Identity
 - Navigation
 - Selection
 - Presentation
 - Feature runtime

 Restoration 只恢复语义状态，
 不恢复 Runtime object graph。
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

     这些仍然只是 Feature / Page
     当前选择的 runtime state。

     当前没有真实 detail route，
     所以暂不进入 Restoration Contract。
     */

    var selectedMusicContent:
        MusicContent?


    var selectedLocalTrack:
        LocalTrack?


    // MARK: - Presentation

    var isQueuePresented:
        Bool


    // MARK: - Features

    let browse:
        FeatureHost<BrowseFeature>


    let libraryFeature:
        FeatureHost<LibraryFeature>


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


        // MARK: Feature Scope

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


    // MARK: - Restored Scene

    /*
     不支持的 Snapshot version
     必须由调用者决定 fallback 行为。

     Core 不偷偷降级或猜测旧格式。
     */

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


    // MARK: - Snapshot

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
