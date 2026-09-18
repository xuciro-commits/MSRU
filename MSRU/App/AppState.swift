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
        SidebarSection? = .listenNow

    var searchText =
        ""


    // MARK: - Catalog

    var selectedMusicContent:
        MusicContent?

    let musicCatalog =
        MusicCatalogStore()


    // MARK: - Openverse

    let openverse =
        OpenverseProviderStore()


    // MARK: - Local Library

    var selectedLocalTrack:
        LocalTrack?

    let localLibrary =
        LocalLibraryStore()


    // MARK: - MSRU Library

    /*
     MSRU 自己的统一资料库。

     它与 LocalLibraryStore 不同：

     LocalLibraryStore
     = 本地文件扫描 / 导入结果

     LibraryStore
     = 用户真正收藏到 MSRU 的音乐资料库

     LibraryTrack 可以来自：
     - Local
     - Openverse
     - Jamendo
     - Apple Music
     - OpenSubsonic
     - Future Providers
     */
    let library =
        LibraryStore()


    // MARK: - Apple Music

    let musicLibrary =
        AppleMusicLibraryStore()


    // MARK: - Playback

    let playback =
        PlaybackController()


    // MARK: - Provider Management

    let providerManager =
        ProviderManagerStore()


    // MARK: - Presentation

    var isQueuePresented =
        true


    // MARK: - Init

    init() {

        /*
         AppState 创建后立即恢复持久化 Library。

         LibraryStore 自己负责：
         Repository
         JSON decoding
         Error state

         AppState 不需要知道 Library.json
         实际存在哪里。
         */
        Task {
            [weak self] in

            guard let self
            else {
                return
            }

            await library
                .load()
        }
    }
}
