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

    // MARK: - Application Scope

    private let application =
        ApplicationModel()


    // MARK: - Window

    private var mainWindowController:
        MainWindowController?


    // MARK: - Launch

    func applicationDidFinishLaunching(
        _ notification:
            Notification
    ) {

        guard
            !isRunningForPreviews
        else {

            return
        }


        application
            .start()


        /*
         当前仍然只有一个主 Window。

         但 SceneModel 已经与 ApplicationModel
         分离。

         未来增加第二个 Window 时，
         只需要再创建一个新的 SceneModel。
         */

        let scene =
            SceneModel(
                application:
                    application
            )


        let windowController =
            MainWindowController(
                scene:
                    scene
            )


        mainWindowController =
            windowController


        windowController
            .showWindow(
                nil
            )


        windowController
            .window?
            .makeKeyAndOrderFront(
                nil
            )
    }


    // MARK: - Reopen

    func applicationShouldHandleReopen(
        _ sender:
            NSApplication,
        hasVisibleWindows flag:
            Bool
    ) -> Bool {

        guard
            !isRunningForPreviews
        else {

            return
                false
        }


        if !flag {

            mainWindowController?
                .showWindow(
                    nil
                )


            mainWindowController?
                .window?
                .makeKeyAndOrderFront(
                    nil
                )
        }


        return
            true
    }


    // MARK: - Termination

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender:
            NSApplication
    ) -> Bool {

        !isRunningForPreviews
    }


    // MARK: - Preview

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
