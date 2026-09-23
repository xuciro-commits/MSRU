//
//  MacSceneCoordinator.swift
//  MSRU
//

#if os(macOS)

import AppKit
import AppFoundation


// MARK: - Restoration Disposition

nonisolated enum MacSceneRestorationDisposition: Equatable, Sendable {
    case preserve
    case remove
}

// MARK: - Scene Lifecycle Policy

nonisolated struct MacSceneLifecyclePolicy: Equatable, Sendable {
    let terminatesAfterLastWindowClosed: Bool

    init(terminatesAfterLastWindowClosed: Bool = false) {
        self.terminatesAfterLastWindowClosed = terminatesAfterLastWindowClosed
    }

    func restorationDisposition(isApplicationTerminating: Bool) -> MacSceneRestorationDisposition {
        isApplicationTerminating ? .preserve : .remove
    }
}

// MARK: - macOS Scene Coordinator

@MainActor
final class MacSceneCoordinator {

    // MARK: - Runtime

    private struct Runtime {

        let scene:
            SceneModel


        let window:
            any MacSceneWindow
    }


    // MARK: - Application

    let application:
        ApplicationModel


    // MARK: - Restoration

    private let restorationStore:
        any SceneRestorationStore


    // MARK: - Window Factory

    private let windowFactory:
        any MacSceneWindowFactory


    // MARK: - Registry

    private var runtimes:
        [
            SceneID:
                Runtime
        ] = [:]


    // MARK: - Lifecycle

    private let lifecyclePolicy:
        MacSceneLifecyclePolicy

    private var isTerminating =
        false


    // MARK: - Live Init

    convenience init(
        application:
            ApplicationModel,
        restorationStore:
            any SceneRestorationStore
    ) {

        self.init(
            application:
                application,
            restorationStore:
                restorationStore,
            windowFactory:
                MainSceneWindowFactory()
        )
    }


    // MARK: - Injectable Init

    init(
        application:
            ApplicationModel,
        restorationStore:
            any SceneRestorationStore,
        windowFactory:
            any MacSceneWindowFactory,
        lifecyclePolicy:
            MacSceneLifecyclePolicy = .init()
    ) {

        self.application =
            application


        self.restorationStore =
            restorationStore


        self.windowFactory =
            windowFactory


        self.lifecyclePolicy =
            lifecyclePolicy
    }


    // MARK: - Application Close Policy

    var terminatesAfterLastWindowClosed:
        Bool {

        lifecyclePolicy
            .terminatesAfterLastWindowClosed
    }


    // MARK: - Start

    func start() {

        application
            .start()


        restoreScenes()
    }


    // MARK: - New Scene

    @discardableResult
    func openNewScene(
        route:
            SceneRoute? = nil
    ) -> SceneID {

        let scene =
            SceneModel(
                application:
                    application
            )


        if let route {

            scene
                .send(
                    .navigate(
                        route
                    )
                )
        }


        restorationStore
            .save(
                scene
                    .restorationSnapshot()
            )


        openWindow(
            for:
                scene
        )


        return
            scene.id
    }


    // MARK: - Scene Routing

    /*
     Platform / External Intent
              ↓
       SceneRoutingRequest
              ↓
       Coordinator policy
              ↓
         SceneCommand
     */

    @discardableResult
    func route(
        _ request:
            SceneRoutingRequest
    ) -> SceneID? {

        switch request.target {

        case .activeOrNew:

            if let activeSceneID {

                return
                    route(
                        request.route,
                        to:
                            activeSceneID
                    )
            }


            if let existingSceneID =
                runtimes
                    .keys
                    .first {

                return
                    route(
                        request.route,
                        to:
                            existingSceneID
                    )
            }


            return
                openNewScene(
                    route:
                        request.route
                )


        case .new:

            return
                openNewScene(
                    route:
                        request.route
                )


        case .scene(
            let sceneID
        ):

            return
                route(
                    request.route,
                    to:
                        sceneID
                )
        }
    }

    func openSpotlightItem(_ identifier: String) {
        guard let item = SpotlightMusicID(rawValue: identifier) else { return }
        let section: SceneSection
        switch item {
        case .track: section = .library
        case .album: section = .albums
        case .artist: section = .artists
        }
        guard let sceneID = route(SceneRoutingRequest(route: .section(section))),
              let scene = runtimes[sceneID]?.scene else { return }
        Task {
            if await SpotlightSelectionRouter.open(identifier: identifier, in: scene) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }


    // MARK: - Route Existing Scene

    private func route(
        _ route:
            SceneRoute,
        to sceneID:
            SceneID
    ) -> SceneID? {

        guard
            let runtime =
                runtimes[
                    sceneID
                ]
        else {

            return nil
        }


        runtime
            .scene
            .send(
                .navigate(
                    route
                )
            )


        /*
         External routing 是 coordinator-owned mutation，
         所以立即更新 semantic snapshot。

         Live Window observation 仍然存在，
         两层并不冲突。
         */

        restorationStore
            .save(
                runtime
                    .scene
                    .restorationSnapshot()
            )


        runtime
            .window
            .activate()


        return
            sceneID
    }


    // MARK: - Active Scene

    private var activeSceneID:
        SceneID? {

        runtimes
            .first {
                $0.value
                    .window
                    .isActive
            }?
            .key
    }


    // MARK: - Activate

    @discardableResult
    func activateScene(
        _ sceneID:
            SceneID
    ) -> Bool {

        guard
            let runtime =
                runtimes[
                    sceneID
                ]
        else {

            return false
        }


        runtime
            .window
            .activate()


        return true
    }


    // MARK: - Reopen

    func reopen() {

        if let activeSceneID {

            activateScene(
                activeSceneID
            )


            return
        }


        if let sceneID =
            runtimes
                .keys
                .first {

            activateScene(
                sceneID
            )


            return
        }


        openNewScene()
    }


    // MARK: - Application Termination

    /// Must be called before AppKit starts tearing down windows.
    ///
    /// This separates application termination from an explicit
    /// user-requested Scene close.
    func prepareForTermination() {

        guard
            !isTerminating
        else {

            return
        }


        isTerminating =
            true


        /*
         Capture every live Scene before Window teardown begins.
         */

        saveScenes()
    }


    // MARK: - Save

    func saveScenes() {

        for runtime
        in runtimes.values {

            restorationStore
                .save(
                    runtime
                        .window
                        .restorationSnapshot()
                )
        }
    }


    // MARK: - Restore

    private func restoreScenes() {

        let snapshots =
            restorationStore
                .loadSnapshots()
                .filter {
                    $0.isSupported
                }


        guard
            !snapshots.isEmpty
        else {

            openNewScene()

            return
        }


        for snapshot
        in snapshots {

            guard
                let scene =
                    SceneModel(
                        application:
                            application,
                        restoration:
                            snapshot
                    )
            else {

                continue
            }


            openWindow(
                for:
                    scene
            )
        }


        if runtimes
            .isEmpty {

            openNewScene()
        }
    }


    // MARK: - Open Window

    private func openWindow(
        for scene:
            SceneModel
    ) {

        if activateScene(
            scene.id
        ) {

            return
        }


        let window =
            windowFactory
                .makeWindow(
                    scene:
                        scene,
                    onSnapshotChange: {
                        [weak self, weak scene]
                        snapshot in

                        guard let self, let scene,
                              snapshot.sceneID == scene.id,
                              self.runtimes[scene.id]?.scene === scene else { return }
                        self.restorationStore.save(snapshot)
                    },
                    onSceneClosed: {
                        [weak self, weak scene]
                        sceneID in

                        guard let self, let scene,
                              sceneID == scene.id,
                              self.runtimes[scene.id]?.scene === scene else { return }
                        self.sceneDidClose(sceneID)
                    }
                )


        runtimes[
            scene.id
        ] =
            Runtime(
                scene:
                    scene,
                window:
                    window
            )


        window
            .activate()
    }


    // MARK: - Close

    private func sceneDidClose(
        _ sceneID:
            SceneID
    ) {

        guard
            let runtime =
                runtimes[
                    sceneID
                ]
        else {

            return
        }


        runtime.scene.close()

        let disposition =
            lifecyclePolicy
                .restorationDisposition(
                    isApplicationTerminating:
                        isTerminating
                )


        switch disposition {

        case .preserve:

            /*
             Capture the final semantic Scene state.

             Window close during application termination must never
             erase the restoration snapshot.
             */

            restorationStore
                .save(
                    runtime
                        .window
                        .restorationSnapshot()
                )


        case .remove:

            /*
             A non-final Scene explicitly closed while the app
             continues running should not return next launch.
             */

            restorationStore
                .remove(
                    sceneID:
                        sceneID
                )
        }


        runtimes[
            sceneID
        ] =
            nil
    }
}

// MARK: - Application Multi Scene Runtime

extension MacSceneCoordinator: ApplicationMultiSceneRuntime {}

#endif
