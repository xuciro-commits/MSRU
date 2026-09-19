//
//  MainSceneWindow.swift
//  MSRU
//

#if os(macOS)

import AppKit


// MARK: - Main Scene Window

@MainActor
final class MainSceneWindow:
    MacSceneWindow {

    // MARK: - Identity

    let sceneID:
        SceneID


    // MARK: - Controller

    private let controller:
        MainWindowController


    // MARK: - Init

    init(
        scene:
            SceneModel,
        onSnapshotChange:
            @escaping @MainActor (
                SceneRestorationSnapshot
            ) -> Void,
        onSceneClosed:
            @escaping @MainActor (
                SceneID
            ) -> Void
    ) {

        self.sceneID =
            scene.id


        self.controller =
            MainWindowController(
                scene:
                    scene,
                onSnapshotChange:
                    onSnapshotChange,
                onSceneClosed:
                    onSceneClosed
            )
    }


    // MARK: - State

    var isActive:
        Bool {

        controller
            .window?
            .isKeyWindow
        ??
        false
    }


    // MARK: - Activate

    func activate() {

        controller
            .showWindow(
                nil
            )


        controller
            .window?
            .makeKeyAndOrderFront(
                nil
            )
    }


    // MARK: - Restoration

    func restorationSnapshot()
        -> SceneRestorationSnapshot {

        controller
            .restorationSnapshot()
    }
}


// MARK: - Factory

@MainActor
final class MainSceneWindowFactory:
    MacSceneWindowFactory {

    func makeWindow(
        scene:
            SceneModel,
        onSnapshotChange:
            @escaping @MainActor (
                SceneRestorationSnapshot
            ) -> Void,
        onSceneClosed:
            @escaping @MainActor (
                SceneID
            ) -> Void
    ) -> any MacSceneWindow {

        MainSceneWindow(
            scene:
                scene,
            onSnapshotChange:
                onSnapshotChange,
            onSceneClosed:
                onSceneClosed
        )
    }
}

#endif
