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

    // MARK: - Platform Composition

    /*
     AppDelegate 只是 macOS lifecycle
     与 Application Commands 的 adapter。

     Window / Scene orchestration
     全部交给 MacSceneCoordinator。
     */

    private let sceneCoordinator:
        MacSceneCoordinator


    // MARK: - Init

    override init() {

        let application =
            ApplicationModel()


        let restorationStore =
            MacSceneRestorationStore()


        self.sceneCoordinator =
            MacSceneCoordinator(
                application:
                    application,
                restorationStore:
                    restorationStore
            )


        super.init()
    }


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


        sceneCoordinator
            .start()
    }


    // MARK: - Commands

    /*
     File -> New Window
     Command-N

     AppDelegate 只转发平台 Command。

     真正的 Scene creation contract
     在 MacSceneCoordinator。
     */

    func openNewScene() {

        guard
            !isRunningForPreviews
        else {

            return
        }


        sceneCoordinator
            .openNewScene()
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

            return false
        }


        guard
            !flag
        else {

            return true
        }


        sceneCoordinator
            .reopen()


        return true
    }


    // MARK: - Termination

    func applicationWillTerminate(
        _ notification:
            Notification
    ) {

        guard
            !isRunningForPreviews
        else {

            return
        }


        sceneCoordinator
            .saveScenes()
    }


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
