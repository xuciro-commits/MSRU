#if os(macOS)

import AppKit
import SwiftUI


@MainActor
final class RootSplitViewController:
    NSSplitViewController {

    let appState:
        AppState


    private(set) var sidebarItem:
        NSSplitViewItem!

    private(set) var contentItem:
        NSSplitViewItem!

    private(set) var queueItem:
        NSSplitViewItem!


    init(
        appState: AppState
    ) {

        self.appState =
            appState

        super.init(
            nibName: nil,
            bundle: nil
        )
    }


    @available(
        *,
        unavailable
    )
    required init?(
        coder: NSCoder
    ) {

        fatalError(
            "init(coder:) is not supported."
        )
    }


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
            "MSRU.MainSplitView"


        /*
         整个 MSRU Window 内部的永久 Ambient Backdrop。

         重点：
         它不是 Sidebar 背景，
         也不是 Main Content 背景。

         它位于：

             App Sidebar
             Main Content
             Settings Sidebar
             Queue Inspector

         所有这些 Pane 的共同底层。

         因此系统 Glass 即使没有可以继续采样的
         Main Content，也会先落到这里，而不是一路
         穿透到 Desktop / 后面的 App。
         */
        splitView.wantsLayer =
            true

        splitView.layer?
            .backgroundColor =
            NSColor.windowBackgroundColor
                .cgColor

        splitView.layer?
            .isOpaque =
            true
    }


    // MARK: - Hosting

    private func makeHostingController<
        Content: View
    >(
        rootView: Content
    ) -> NSHostingController<Content> {

        let controller =
            NSHostingController(
                rootView:
                    rootView
            )


        /*
         AppKit 决定 Pane / Window geometry。

         不允许 SwiftUI intrinsic size
         再反向修改 SplitView 尺寸。
         */
        controller.sizingOptions =
            []


        return controller
    }


    // MARK: - Sidebar

    private func configureSidebar() {

        let hostingController =
            makeHostingController(
                rootView:
                    SidebarPaneView(
                        appState:
                            appState
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


        /*
         Sidebar 自己不画实色背景。

         继续让 sidebarWithViewController
         提供系统原生 Sidebar Glass。

         Bottom accessory 也不再承担
         Sidebar Toggle。
         */
        let bottomAccessory =
            SplitAccessoryHostingController(
                rootView:
                    SidebarBottomAccessoryView(
                        onOpenSettings: {
                            [weak self] in

                            self?
                                .appState
                                .selectedSection =
                                .settings
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
                        appState:
                            appState
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
                            appState.playback,
                        onToggleQueue: {
                            [weak self] in

                            self?
                                .toggleInspector(
                                    nil
                                )
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

        /*
         Queue Pane 自己不再提供第二层实色 Surface。

         List / ScrollView 背景隐藏，
         让原生 Inspector Glass 真正露出来。

         这是保持 Apple Inspector 语义的情况下，
         能做到的最干净、最透明状态。
         */
        let queueView =
            QueuePaneView(
                playback:
                    appState.playback
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
            !appState
                .isQueuePresented


        let headerAccessory =
            SplitAccessoryHostingController(
                rootView:
                    QueueHeaderView(
                        onClear: {
                            [weak self] in

                            self?
                                .appState
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
}

#endif
