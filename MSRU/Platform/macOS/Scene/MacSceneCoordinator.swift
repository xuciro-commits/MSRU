//
//  MacSceneCoordinator.swift
//  MSRU
//

#if os(macOS)

import AppKit


// MARK: - macOS Scene Coordinator

/*
 MacSceneCoordinator 是 macOS 平台层的
 Scene orchestration owner。

 它管理：

 Application Scope
        │
        ├── Scene A -> Window A
        ├── Scene B -> Window B
        └── Scene C -> Window C

 Coordinator 不知道具体 Window
 是 NSWindowController 还是测试 Double。
 */

@MainActor
final class MacSceneCoordinator {

    // MARK: - Application

    private let application:
        ApplicationModel


    // MARK: - Restoration

    private let restorationStore:
        any SceneRestorationStore


    // MARK: - Window Factory

    private let windowFactory:
        any MacSceneWindowFactory


    // MARK: - Registry

    private var windows:
        [
            SceneID:
                any MacSceneWindow
        ] = [:]


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
            any MacSceneWindowFactory
    ) {

        self.application =
            application


        self.restorationStore =
            restorationStore


        self.windowFactory =
            windowFactory
    }


    // MARK: - Start

    func start() {

        application
            .start()


        restoreScenes()
    }


    // MARK: - New Scene

    @discardableResult
    func openNewScene()
        -> SceneID {

        let scene =
            SceneModel(
                application:
                    application
            )


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


    // MARK: - Activate

    @discardableResult
    func activateScene(
        _ sceneID:
            SceneID
    ) -> Bool {

        guard
            let window =
                windows[
                    sceneID
                ]
        else {

            return false
        }


        window
            .activate()


        return true
    }


    // MARK: - Reopen

    func reopen() {

        if let window =
            windows
                .values
                .first {

            window
                .activate()


            return
        }


        openNewScene()
    }


    // MARK: - Save

    func saveScenes() {

        for window
        in windows.values {

            restorationStore
                .save(
                    window
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


        /*
         Store 中可能存在数据，
         但全部因为版本或数据问题
         无法恢复。

         App 仍然必须拥有至少一个 Scene。
         */

        if windows
            .isEmpty {

            openNewScene()
        }
    }


    // MARK: - Open Window

    private func openWindow(
        for scene:
            SceneModel
    ) {

        /*
         同一个 SceneID 永远只能对应
         一个 active Window runtime。
         */

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
                        [weak self]
                        snapshot in

                        self?
                            .restorationStore
                            .save(
                                snapshot
                            )
                    },
                    onSceneClosed: {
                        [weak self]
                        sceneID in

                        self?
                            .sceneDidClose(
                                sceneID
                            )
                    }
                )


        windows[
            scene.id
        ] =
            window


        window
            .activate()
    }


    // MARK: - Close

    private func sceneDidClose(
        _ sceneID:
            SceneID
    ) {

        restorationStore
            .remove(
                sceneID:
                    sceneID
            )


        windows[
            sceneID
        ] =
            nil
    }
}

#endif
