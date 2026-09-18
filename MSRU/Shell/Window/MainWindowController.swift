#if os(macOS)

import AppKit


@MainActor
final class MainWindowController:
    NSWindowController,
    NSToolbarDelegate {

    private let appState:
        AppState

    private let rootSplitViewController:
        RootSplitViewController

    private let mainToolbar =
        NSToolbar(
            identifier:
                "MSRU.MainToolbar"
        )


    init(
        appState: AppState
    ) {

        self.appState =
            appState

        self.rootSplitViewController =
            RootSplitViewController(
                appState:
                    appState
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


        /*
         SplitView 必须先进入 Window。

         Tracking Separator 要求它跟踪的 splitView
         已经存在于同一个 Window 中。
         */
        window.contentViewController =
            rootSplitViewController


        super.init(
            window:
                window
        )


        configureToolbar()
        configureWindow(
            window
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


    // MARK: - Window

    private func configureWindow(
        _ window: NSWindow
    ) {

        window.title =
            "MSRU"

        window.titleVisibility =
            .hidden

        window.titlebarAppearsTransparent =
            true

        window.titlebarSeparatorStyle =
            .none


        /*
         Apple 原生 unified toolbar。

         Sidebar Toggle 会存在于 Window Chrome 层，
         而不是 Sidebar 内容层。
         */
        window.toolbarStyle =
            .unified

        window.toolbar =
            mainToolbar

        mainToolbar.isVisible =
            true


        window.collectionBehavior.insert(
            .fullScreenPrimary
        )


        window.minSize =
            NSSize(
                width: 900,
                height: 600
            )

        window.contentMinSize =
            NSSize(
                width: 900,
                height: 600
            )


        window.isReleasedWhenClosed =
            false

        window.center()
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


    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {

        [
            .toggleSidebar,
            .sidebarTrackingSeparator
        ]
    }


    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {

        [
            .toggleSidebar,
            .sidebarTrackingSeparator
        ]
    }


    /*
     Toolbar 是代码创建的，所以保留 delegate factory。

     这里使用的两个都是 AppKit 标准 Identifier；
     AppKit 会自动创建标准 item，因此这里没有自定义 item。
     */
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier:
            NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {

        nil
    }
}

#endif
