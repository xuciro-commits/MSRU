//
//  MainSceneWindow.swift
//  MSRU
//

#if os(macOS)

import AppKit
import Observation

import AppFoundation


// MARK: - Scene Window Protocol

@MainActor
protocol MacSceneWindow: AnyObject {
    var sceneID: SceneID { get }
    var isActive: Bool { get }
    func activate()
    func restorationSnapshot() -> SceneRestorationSnapshot
}

extension MacSceneWindow {
    var isActive: Bool {
        false
    }
}

// MARK: - Factory

@MainActor
protocol MacSceneWindowFactory: AnyObject {
    func makeWindow(
        scene: SceneModel,
        onSnapshotChange: @escaping @MainActor (SceneRestorationSnapshot) -> Void,
        onSceneClosed: @escaping @MainActor (SceneID) -> Void
    ) -> any MacSceneWindow
}

// MARK: - Main Scene Window

@MainActor
final class MainSceneWindow:
    NSObject,
    MacSceneWindow,
    NSWindowDelegate {

    // MARK: - Identity

    let sceneID:
        SceneID


    // MARK: - Scene

    private let scene:
        SceneModel


    // MARK: - Window Composition

    private let composition:
        MSRUMacWindowComposition


    // MARK: - Lifecycle Callbacks

    private let onSnapshotChange:
        @MainActor (
            SceneRestorationSnapshot
        ) -> Void

    private let onSceneClosed:
        @MainActor (
            SceneID
        ) -> Void


    // MARK: - Init

    init(
        scene:
            SceneModel,
        splitAutosaveName: String? = "MSRU.MainSplitView",
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

        self.scene =
            scene

        self.onSnapshotChange =
            onSnapshotChange

        self.onSceneClosed =
            onSceneClosed

        self.composition =
            MSRUMacWindowComposition(
                scene:
                    scene,
                splitAutosaveName: splitAutosaveName
            )


        super.init()


        composition
            .windowController
            .window?
            .delegate =
                self


        composition.windowController.window?.setAccessibilityIdentifier("scene." + scene.id.description)
        observeRestorationState()
    }


    // MARK: - Window State

    var isActive:
        Bool {

        composition
            .windowController
            .window?
            .isKeyWindow
        ??
        false
    }


    // MARK: - Activation

    func activate() {

        composition
            .windowController
            .showWindow(
                nil
            )


        composition
            .windowController
            .window?
            .makeKeyAndOrderFront(
                nil
            )
    }


    // MARK: - Restoration

    func restorationSnapshot()
        -> SceneRestorationSnapshot {

        scene
            .restorationSnapshot()
    }


    // MARK: - Restoration Observation

    private func observeRestorationState() {

        guard !scene.isClosed else { return }

        withObservationTracking {

            _ =
                scene
                    .navigation
                    .section

            _ =
                scene
                    .isQueuePresented

        } onChange: {
            [weak self]
            in

            Task {
                @MainActor
                [weak self]
                in

                guard
                    let self, !self.scene.isClosed
                else {

                    return
                }


                onSnapshotChange(
                    scene
                        .restorationSnapshot()
                )


                observeRestorationState()
            }
        }
    }


    // MARK: - NSWindowDelegate

    func windowWillClose(
        _ notification:
            Notification
    ) {

        onSceneClosed(
            sceneID
        )
    }
}


// MARK: - Factory

@MainActor
final class MainSceneWindowFactory:
    MacSceneWindowFactory {

    private let splitAutosaveName: String?

    init(splitAutosaveName: String? = "MSRU.MainSplitView") {
        self.splitAutosaveName = splitAutosaveName
    }

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
            splitAutosaveName: splitAutosaveName,
            onSnapshotChange:
                onSnapshotChange,
            onSceneClosed:
                onSceneClosed
        )
    }
}

#endif
