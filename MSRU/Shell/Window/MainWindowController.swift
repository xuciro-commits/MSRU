#if os(macOS)

import AppKit


@MainActor
final class MainWindowController:
    NSWindowController {

    private let appState:
        AppState

    private let rootSplitViewController:
        RootSplitViewController


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
                contentViewController:
                    rootSplitViewController
            )


        super.init(
            window:
                window
        )


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


    private func configureWindow(
        _ window: NSWindow
    ) {

        window.styleMask
            .insert(
                .fullSizeContentView
            )

        window.titlebarAppearsTransparent =
            true

        window.titleVisibility =
            .hidden

        window.titlebarSeparatorStyle =
            .none

        window.toolbar =
            nil

        window.title =
            "MSRU"


        window.setContentSize(
            NSSize(
                width: 1200,
                height: 760
            )
        )


        window.minSize =
            NSSize(
                width: 900,
                height: 600
            )


        window.isReleasedWhenClosed =
            false


        window.setFrameAutosaveName(
            "MSRU.MainWindow"
        )


        window.center()
    }
}

#endif
