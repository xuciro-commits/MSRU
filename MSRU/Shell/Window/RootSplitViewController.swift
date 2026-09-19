#if os(macOS)

import AppKit
import SwiftUI


@MainActor
final class RootSplitViewController:
    NSSplitViewController {

    // MARK: - Scene

    let scene:
        SceneModel


    private(set) var sidebarItem:
        NSSplitViewItem!


    private(set) var contentItem:
        NSSplitViewItem!


    private(set) var queueItem:
        NSSplitViewItem!


    // MARK: - Init

    init(
        scene:
            SceneModel
    ) {

        self.scene =
            scene


        super.init(
            nibName:
                nil,
            bundle:
                nil
        )
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


    // MARK: - Lifecycle

    override func viewDidLoad() {

        super.viewDidLoad()


        configureSplitView()

        configureSidebar()

        configureContent()

        configureQueue()
    }


    // MARK: - Split View

    private func configureSplitView() {

        splitView.isVertical =
            true


        splitView.autosaveName =
            "MSRU.MainSplitView."
            +
            scene
                .id
                .rawValue
                .uuidString


        /*
         整个 MSRU Window 内部的永久 Ambient Backdrop。

         它不是 Sidebar 背景，
         也不是 Main Content 背景。

         它是所有 Pane 的共同底层。
         */

        splitView.wantsLayer =
            true


        splitView.layer?
            .backgroundColor =
            NSColor
                .windowBackgroundColor
                .cgColor


        splitView.layer?
            .isOpaque =
            true
    }


    // MARK: - Hosting

    private func makeHostingController<
        Content:
            View
    >(
        rootView:
            Content
    ) -> NSHostingController<Content> {

        let controller =
            NSHostingController(
                rootView:
                    rootView
            )


        /*
         Geometry 由 AppKit SplitView 管理。

         不允许 SwiftUI intrinsic content size
         反向修改 Pane 尺寸。
         */

        controller.sizingOptions =
            []


        return
            controller
    }


    // MARK: - Sidebar

    private func configureSidebar() {

        let hostingController =
            makeHostingController(
                rootView:
                    SidebarPaneView(
                        scene:
                            scene
                    )
            )


        let item =
            NSSplitViewItem(
                sidebarWithViewController:
                    hostingController
            )


        item.canCollapse =
            true


        item.allowsFullHeightLayout =
            true


        item.minimumThickness =
            180


        item.maximumThickness =
            280


        let bottomAccessory =
            SplitAccessoryHostingController(
                rootView:
                    SidebarBottomAccessoryView(
                        onOpenSettings: {
                            [weak self]
                            in

                            self?
                                .scene
                                .navigation
                                .select(
                                    .settings
                                )
                        }
                    )
            )


        item.addBottomAlignedAccessoryViewController(
            bottomAccessory
        )


        sidebarItem =
            item


        addSplitViewItem(
            item
        )
    }


    // MARK: - Main Content

    private func configureContent() {

        let hostingController =
            makeHostingController(
                rootView:
                    MainContentView(
                        scene:
                            scene
                    )
            )


        let item =
            NSSplitViewItem(
                viewController:
                    hostingController
            )


        item.canCollapse =
            false


        item.minimumThickness =
            500


        item.automaticallyAdjustsSafeAreaInsets =
            true


        let playerAccessory =
            SplitAccessoryHostingController(
                rootView:
                    MiniPlayerAccessoryView(
                        playback:
                            scene
                                .application
                                .playback,
                        onToggleQueue: {
                            [weak self]
                            in

                            self?
                                .toggleQueueInspector()
                        }
                    )
            )


        item.addBottomAlignedAccessoryViewController(
            playerAccessory
        )


        contentItem =
            item


        addSplitViewItem(
            item
        )
    }


    // MARK: - Queue Inspector

    private func configureQueue() {

        let queueView =
            QueuePaneView(
                playback:
                    scene
                        .application
                        .playback
            )
            .scrollContentBackground(
                .hidden
            )
            .background(
                Color.clear
            )


        let hostingController =
            makeHostingController(
                rootView:
                    queueView
            )


        let item =
            NSSplitViewItem(
                inspectorWithViewController:
                    hostingController
            )


        item.canCollapse =
            true


        item.allowsFullHeightLayout =
            true


        item.minimumThickness =
            280


        item.maximumThickness =
            420


        item.isCollapsed =
            !scene
                .isQueuePresented


        let headerAccessory =
            SplitAccessoryHostingController(
                rootView:
                    QueueHeaderView(
                        onClear: {
                            [weak self]
                            in

                            self?
                                .scene
                                .application
                                .playback
                                .clearUpcoming()
                        }
                    )
                    .background(
                        Color.clear
                    )
            )


        item.addTopAlignedAccessoryViewController(
            headerAccessory
        )


        queueItem =
            item


        addSplitViewItem(
            item
        )
    }


    // MARK: - Presentation

    private func toggleQueueInspector() {

        toggleInspector(
            nil
        )


        /*
         SplitView 是实际 presentation owner。

         SceneModel 保存 restoration-friendly
         presentation state。
         */

        scene.isQueuePresented =
            !(queueItem?
                .isCollapsed
                ?? true)
    }
}

#endif
