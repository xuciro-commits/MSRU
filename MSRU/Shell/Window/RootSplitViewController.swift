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
    }


    // MARK: - Sidebar

    private func configureSidebar() {

        let hostingController =
            NSHostingController(
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


        let bottomAccessory =
            SplitAccessoryHostingController(
                rootView:
                    SidebarBottomAccessoryView(
                        onToggleSidebar: {
                            [weak self] in

                            self?
                                .toggleSidebar(
                                    nil
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


    // MARK: - Content

    private func configureContent() {

        let hostingController =
            NSHostingController(
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
                            appState.playback
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


    // MARK: - Queue

    private func configureQueue() {

        let hostingController =
            NSHostingController(
                rootView:
                    QueuePaneView(
                        playback:
                            appState.playback
                    )
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
