#if os(macOS)

import AppKit
import Observation
import AppFoundation


@MainActor
final class MainWindowController:
    NSWindowController,
    NSToolbarDelegate,
    NSWindowDelegate {

    // MARK: - Scene

    private let scene:
        SceneModel


    // MARK: - Restoration Callbacks

    private let onSnapshotChange:
        @MainActor (
            SceneRestorationSnapshot
        ) -> Void


    private let onSceneClosed:
        @MainActor (
            SceneID
        ) -> Void


    /*
     windowShouldClose 是用户主动 Close
     的语义入口。

     App termination 不走这个入口。
     */

    private var shouldDiscardRestorationOnClose =
        false


    // MARK: - Root

    private let rootSplitViewController:
        RootSplitViewController


    // MARK: - Toolbar

    private let mainToolbar =
        NSToolbar(
            identifier:
                "MSRU.MainToolbar"
        )


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

        self.scene =
            scene


        self.onSnapshotChange =
            onSnapshotChange


        self.onSceneClosed =
            onSceneClosed


        self.rootSplitViewController =
            RootSplitViewController(
                scene:
                    scene
            )


        let window =
            NSWindow(
                contentRect:
                    NSRect(
                        x: 0,
                        y: 0,
                        width: 1200,
                        height: 760
                    ),
                styleMask:
                    [
                        .titled,
                        .closable,
                        .miniaturizable,
                        .resizable,
                        .fullSizeContentView
                    ],
                backing:
                    .buffered,
                defer:
                    false
            )


        window.contentViewController =
            rootSplitViewController


        super.init(
            window:
                window
        )


        window.delegate =
            self


        configureToolbar()


        configureWindow(
            window
        )


        observeRestorableSceneState()


        publishSnapshot()
    }


    @available(
        *,
        unavailable
    )
    required init?(
        coder:
            NSCoder
    ) {

        fatalError(
            "init(coder:) is not supported."
        )
    }


    // MARK: - Restoration

    func restorationSnapshot()
        -> SceneRestorationSnapshot {

        scene
            .restorationSnapshot()
    }


    private func publishSnapshot() {

        onSnapshotChange(
            scene
                .restorationSnapshot()
        )
    }


    /*
     Observation tracking 是 one-shot。

     每次变化发生以后：

     1. publish snapshot
     2. 重新建立 tracking

     这样 View 不需要手动调用 save()。
     */

    private func observeRestorableSceneState() {

        withObservationTracking {

            _ =
                scene
                    .navigation
                    .section


            _ =
                scene
                    .isQueuePresented

        } onChange: {
            [weak self] in

            Task {
                @MainActor
                [weak self] in

                guard
                    let self
                else {

                    return
                }


                self
                    .publishSnapshot()


                self
                    .observeRestorableSceneState()
            }
        }
    }


    // MARK: - Window

    private func configureWindow(
        _ window:
            NSWindow
    ) {

        window.title =
            "MSRU"


        window.titleVisibility =
            .hidden


        window.titlebarAppearsTransparent =
            true


        window.titlebarSeparatorStyle =
            .none


        window.toolbarStyle =
            .unified


        window.toolbar =
            mainToolbar


        mainToolbar.isVisible =
            true


        window.collectionBehavior
            .insert(
                .fullScreenPrimary
            )


        window.minSize =
            NSSize(
                width:
                    900,
                height:
                    600
            )


        window.contentMinSize =
            NSSize(
                width:
                    900,
                height:
                    600
            )


        window.isReleasedWhenClosed =
            false


        // MARK: Frame Restoration

        /*
         Window geometry 属于 AppKit。

         Scene semantic state 属于
         SceneRestorationSnapshot。

         两者使用同一个 SceneID
         作为 identity bridge。
         */

        let frameAutosaveName =
            "MSRU.SceneWindow."
            +
            scene
                .id
                .rawValue
                .uuidString


        let restoredFrame =
            window
                .setFrameUsingName(
                    frameAutosaveName
                )


        _ =
            window
                .setFrameAutosaveName(
                    frameAutosaveName
                )


        if !restoredFrame {

            window.center()
        }
    }


    // MARK: - Toolbar

    private func configureToolbar() {

        mainToolbar.delegate =
            self


        mainToolbar.displayMode =
            .iconOnly


        mainToolbar.allowsUserCustomization =
            false


        mainToolbar.autosavesConfiguration =
            false
    }


    // MARK: - Window Delegate

    func windowShouldClose(
        _ sender:
            NSWindow
    ) -> Bool {

        shouldDiscardRestorationOnClose =
            true


        return true
    }


    func windowWillClose(
        _ notification:
            Notification
    ) {

        if shouldDiscardRestorationOnClose {

            onSceneClosed(
                scene.id
            )

        } else {

            /*
             Application termination。

             Scene 仍然存在于下次启动的
             restoration set 中。
             */

            publishSnapshot()
        }
    }


    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(
        _ toolbar:
            NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        [
            .toggleSidebar,
            .sidebarTrackingSeparator
        ]
    }


    func toolbarAllowedItemIdentifiers(
        _ toolbar:
            NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        [
            .toggleSidebar,
            .sidebarTrackingSeparator
        ]
    }


    func toolbar(
        _ toolbar:
            NSToolbar,
        itemForItemIdentifier itemIdentifier:
            NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag:
            Bool
    ) -> NSToolbarItem? {

        nil
    }
}

#endif
