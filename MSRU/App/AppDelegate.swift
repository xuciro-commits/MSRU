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

    private let sceneCoordinator:
        MacSceneCoordinator


    // MARK: - External Routing

    private let routeCodec =
        SceneRouteURLCodec(
            scheme:
                "msru"
        )


    /*
     macOS 可能在 Application launch
     完成之前交付 URL。

     所以 External Intent 必须允许 buffering。
     */

    private var pendingExternalRoutes:
        [SceneRoute] = []


    private var hasStarted =
        false


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


        hasStarted =
            true


        flushPendingExternalRoutes()
    }


    // MARK: - New Window

    func openNewScene() {

        guard
            !isRunningForPreviews
        else {

            return
        }


        sceneCoordinator
            .openNewScene()
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


        let routes =
            urls
                .compactMap {
                    routeCodec
                        .decode(
                            $0
                        )
                }


        guard
            hasStarted
        else {

            pendingExternalRoutes
                .append(
                    contentsOf:
                        routes
                )


            return
        }


        route(
            routes
        )
    }


    private func flushPendingExternalRoutes() {

        guard
            !pendingExternalRoutes
                .isEmpty
        else {

            return
        }


        let routes =
            pendingExternalRoutes


        pendingExternalRoutes
            .removeAll()


        route(
            routes
        )
    }


    private func route(
        _ routes:
            [SceneRoute]
    ) {

        for route
        in routes {

            sceneCoordinator
                .route(
                    SceneRoutingRequest(
                        route:
                            route,
                        target:
                            .activeOrNew
                    )
                )
        }
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
