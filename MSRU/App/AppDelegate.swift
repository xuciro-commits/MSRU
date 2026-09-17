//
//  AppDelegate.swift
//  MSRU
//

#if os(macOS)

import AppKit


@MainActor
final class AppDelegate:
    NSObject,
    NSApplicationDelegate {

    private let appState =
        AppState()

    private var mainWindowController:
        MainWindowController?


    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        guard
            !isRunningForPreviews
        else {
            return
        }


        let windowController =
            MainWindowController(
                appState:
                    appState
            )

        mainWindowController =
            windowController


        windowController
            .showWindow(nil)

        windowController
            .window?
            .makeKeyAndOrderFront(
                nil
            )
    }


    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {

        guard
            !isRunningForPreviews
        else {
            return false
        }


        if !flag {

            mainWindowController?
                .showWindow(nil)

            mainWindowController?
                .window?
                .makeKeyAndOrderFront(
                    nil
                )
        }


        return true
    }


    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {

        !isRunningForPreviews
    }


    private var isRunningForPreviews:
        Bool {

        let environment =
            ProcessInfo
                .processInfo
                .environment


        return
            environment[
                "XCODE_RUNNING_FOR_PREVIEWS"
            ] == "1"
            ||
            environment[
                "XCODE_RUNNING_FOR_PLAYGROUNDS"
            ] == "1"
    }
}

#endif
