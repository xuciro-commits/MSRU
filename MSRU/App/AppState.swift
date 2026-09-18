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


    // MARK: - MSRU Library

    let library:
        LibraryStore


    // MARK: - Apple Music

    let musicLibrary =
        AppleMusicLibraryStore()


    // MARK: - Playback

    let playback:
        PlaybackController


    // MARK: - Browse Feature

    let browse:
        BrowseFeatureHost


    // MARK: - Provider Management

    let providerManager =
        ProviderManagerStore()


    // MARK: - Presentation

    var isQueuePresented =
        true


    // MARK: - Init

    init() {

        let library =
            LibraryStore()


        let playback =
            PlaybackController()


        self.library =
            library


        self.playback =
            playback


        self.browse =
            BrowseFeatureHost(
                service:
                    BrowseFeature.Service(
                        searchClient:
                            .live,
                        playback:
                            playback,
                        library:
                            library
                    )
            )


        /*
         恢复 MSRU 自己的持久化 Library。

         Repository 的具体文件位置
         仍由 LibraryStore /
         JSONLibraryRepository 管理。
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
