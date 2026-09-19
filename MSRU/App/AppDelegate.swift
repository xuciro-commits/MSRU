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

    // MARK: - Platform Scene Runtime

    private let sceneCoordinator:
        MacSceneCoordinator


    // MARK: - Command Runtime

    private let commandRuntime:
        MultiSceneApplicationCommandRuntime


    // MARK: - Lifecycle Runtime

    /*
     Platform delegate 只负责把
     platform lifecycle event
     映射到 Foundation lifecycle semantic。
     */

    private let lifecycleRuntime:
        ApplicationLifecycleRuntime


    // MARK: - External Command Source

    private let externalURLSource =
        SceneRouteURLCommandSource(
            scheme:
                "msru"
        )


    // MARK: - Init

    override init() {

        let application =
            ApplicationModel()


        let restorationStore =
            MacSceneRestorationStore()


        let sceneCoordinator =
            MacSceneCoordinator(
                application:
                    application,
                restorationStore:
                    restorationStore
            )


        let commandRuntime =
            MultiSceneApplicationCommandRuntime(
                runtime:
                    sceneCoordinator
            )


        let lifecycleRuntime =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commandRuntime
            )


        self.sceneCoordinator =
            sceneCoordinator


        self.commandRuntime =
            commandRuntime


        self.lifecycleRuntime =
            lifecycleRuntime


        super.init()
    }


    // MARK: - Command Entry

    @discardableResult
    func send(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        commandRuntime
            .send(
                command
            )
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


        lifecycleRuntime
            .beginBootstrap()


        /*
         真正的 platform bootstrap。

         Foundation lifecycle
         不知道里面发生了什么。
         */

        sceneCoordinator
            .start()


        lifecycleRuntime
            .markReady()
    }


    // MARK: - External URL

    func application(
        _ application:
            NSApplication,
        open urls:
            [URL]
    ) {

        guard
            !isRunningForPreviews
        else {

            return
        }


        let commands =
            urls
                .compactMap {
                    externalURLSource
                        .command(
                            from:
                                $0
                        )
                }


        commandRuntime
            .send(
                commands
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


        lifecycleRuntime
            .terminate()


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
