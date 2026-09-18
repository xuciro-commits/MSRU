//
//  AppState.swift
//  MSRU
//

import Foundation
import Observation


@MainActor
@Observable
final class AppState {

    // MARK: - Navigation

    var selectedSection:
        SidebarSection? =
            .listenNow


    // MARK: - Catalog

    var selectedMusicContent:
        MusicContent?


    let musicCatalog =
        MusicCatalogStore()


    // MARK: - Local Library

    var selectedLocalTrack:
        LocalTrack?


    let localLibrary =
        LocalLibraryStore()


    // MARK: - Application Library

    let library:
        LibraryStore


    // MARK: - Apple Music

    let musicLibrary =
        AppleMusicLibraryStore()


    // MARK: - Playback

    let playback:
        PlaybackController


    // MARK: - Dependencies

    /*
     Application Dependency Snapshot。

     Application-scoped references
     在这里被创建一次，然后交给
     Scene / Feature runtime。
     */

    let dependencies:
        DependencyValues


    // MARK: - Features

    let browse:
        FeatureHost<BrowseFeature>


    let libraryFeature:
        FeatureHost<LibraryFeature>


    // MARK: - Provider Management

    let providerManager =
        ProviderManagerStore()


    // MARK: - Presentation

    var isQueuePresented =
        true


    // MARK: - Init

    init() {

        // MARK: Application Scope

        let library =
            LibraryStore()


        let playback =
            PlaybackController()


        // MARK: Dependency Composition

        var dependencies =
            DependencyValues
                .live


        dependencies.library =
            library


        dependencies.playback =
            playback


        dependencies.openverseSearch =
            .live


        // MARK: Store Application Scope

        self.library =
            library


        self.playback =
            playback


        self.dependencies =
            dependencies


        // MARK: Feature Scope

        self.browse =
            withDependencies(
                dependencies
            ) {

                FeatureHost<BrowseFeature>(
                    service:
                        BrowseFeature
                            .Service()
                )
            }


        self.libraryFeature =
            withDependencies(
                dependencies
            ) {

                FeatureHost<LibraryFeature>(
                    service:
                        LibraryFeature
                            .Service()
                )
            }


        // MARK: Restore Library

        /*
         LibraryStore 属于 Application Scope。

         因此恢复工作不挂在 Library Feature
         或某个具体 View 的 appeared 生命周期上。
         */

        Task {
            [weak self]
            in

            guard
                let self
            else {

                return
            }


            await library
                .load()
        }
    }
}
