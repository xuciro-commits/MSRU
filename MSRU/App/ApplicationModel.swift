//
//  ApplicationModel.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation


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

    // MARK: - Catalog

    let musicCatalog:
        MusicCatalogStore


    // MARK: - Local Library

    let localLibrary:
        LocalLibraryStore


    // MARK: - Library

    let library:
        LibraryStore


    // MARK: - Apple Music

    let musicLibrary:
        AppleMusicLibraryStore


    // MARK: - Playback

    let playback:
        PlaybackController


    // MARK: - Providers

    let providerManager:
        ProviderManagerStore


    // MARK: - Dependencies

    /*
     Application dependency snapshot。

     Scene / Feature runtime 从这里继承依赖，
     但不重新创建 application-scoped service。
     */

    let dependencies:
        DependencyValues


    // MARK: - Lifecycle

    private(set) var hasStarted =
        false

    private(set) var startupTask:
        Task<Void, Never>?

    private(set) var isTerminated =
        false


    // MARK: - Live Init

    /*
     Live composition root。

     所有 @MainActor dependency
     都在 ApplicationModel 自己的 MainActor
     initializer body 内创建。

     不使用 default argument expressions，
     避免 Swift 6 actor-isolation 泄漏。
     */

    convenience init() {

        self.init(
            musicCatalog:
                MusicCatalogStore(),
            localLibrary:
                LocalLibraryStore(),
            library:
                LibraryStore(),
            musicLibrary:
                AppleMusicLibraryStore(),
            playback:
                PlaybackController(),
            providerManager:
                ProviderManagerStore(),
            openverseSearch:
                .live
        )
    }


    // MARK: - Injected Init

    /*
     Preview / Test / future composition root
     可以显式注入整套 Application Scope。

     这里故意没有默认值。

     原因：
     default argument 本身并不继承
     initializer 的 MainActor isolation。
     */

    init(
        musicCatalog:
            MusicCatalogStore,
        localLibrary:
            LocalLibraryStore,
        library:
            LibraryStore,
        musicLibrary:
            AppleMusicLibraryStore,
        playback:
            PlaybackController,
        providerManager:
            ProviderManagerStore,
        openverseSearch:
            OpenverseSearchClient
    ) {

        self.musicCatalog =
            musicCatalog


        self.localLibrary =
            localLibrary


        self.library =
            library


        self.musicLibrary =
            musicLibrary


        self.playback =
            playback


        self.providerManager =
            providerManager


        // MARK: Dependency Composition

        var dependencies =
            DependencyValues
                .live


        dependencies.library =
            library


        dependencies.playback =
            playback


        dependencies.openverseSearch =
            openverseSearch


        self.dependencies =
            dependencies
    }


    // MARK: - Start

    /*
     Application startup 必须 idempotent。

     macOS AppDelegate 与未来 iPad Scene
     都可以安全调用 start()，
     但 application-scoped restore 只执行一次。
     */

    func start() {

        guard
            !hasStarted,
            !isTerminated
        else {

            return
        }


        hasStarted =
            true


        let library =
            library


        startupTask = Task {

            await library
                .load()
        }
    }


    // MARK: - Terminate

    func terminate() {

        guard
            !isTerminated
        else {

            return
        }


        isTerminated =
            true


        startupTask?
            .cancel()
    }
}
