#if os(iOS)

import SwiftUI


struct iPadRootView:
    View {

    // MARK: - Application

    let application:
        ApplicationModel


    // MARK: - External Routing

    private let routeCodec =
        SceneRouteURLCodec(
            scheme:
                "msru"
        )


    @State
    private var pendingRoute:
        SceneRoute?


    // MARK: - Platform Restoration

    @SceneStorage(
        "MSRU.Scene.RestorationSnapshot"
    )
    private var restorationJSON:
        String?


    // MARK: - Scene Runtime

    @State
    private var scene:
        SceneModel?


    // MARK: - Init

    init(
        application:
            ApplicationModel
    ) {

        self.application =
            application
    }


    // MARK: - Body

    var body:
        some View {

        Group {

            if let scene {

                sceneContent(
                    scene
                )

            } else {

                ProgressView()
                    .task {

                        restoreOrCreateScene()
                    }
            }
        }
        .onOpenURL {
            url in

            handleExternalURL(
                url
            )
        }
    }


    // MARK: - Content

    private func sceneContent(
        _ scene:
            SceneModel
    ) -> some View {

        NavigationSplitView {

            SidebarPaneView(
                scene:
                    scene
            )

        } detail: {

            MainContentView(
                scene:
                    scene
            )
        }
        .onChange(
            of:
                scene
                    .navigation
                    .section
        ) {

            persist(
                scene
            )
        }
        .onChange(
            of:
                scene
                    .isQueuePresented
        ) {

            persist(
                scene
            )
        }
    }


    // MARK: - External URL

    @MainActor
    private func handleExternalURL(
        _ url:
            URL
    ) {

        guard
            let route =
                routeCodec
                    .decode(
                        url
                    )
        else {

            return
        }


        guard
            let scene
        else {

            pendingRoute =
                route

            return
        }


        scene
            .send(
                .navigate(
                    route
                )
            )


        persist(
            scene
        )
    }


    // MARK: - Bootstrap

    @MainActor
    private func restoreOrCreateScene() {

        guard
            scene == nil
        else {

            return
        }


        let resolvedScene:
            SceneModel


        if let restorationJSON,
           let data =
            restorationJSON.data(
                using:
                    .utf8
            ),
           let snapshot =
            try? JSONDecoder()
                .decode(
                    SceneRestorationSnapshot
                        .self,
                    from:
                        data
                ),
           let restoredScene =
            SceneModel(
                application:
                    application,
                restoration:
                    snapshot
            ) {

            resolvedScene =
                restoredScene

        } else {

            resolvedScene =
                SceneModel(
                    application:
                        application
                )
        }


        if let pendingRoute {

            resolvedScene
                .send(
                    .navigate(
                        pendingRoute
                    )
                )


            self.pendingRoute =
                nil
        }


        scene =
            resolvedScene


        persist(
            resolvedScene
        )
    }


    // MARK: - Persist

    @MainActor
    private func persist(
        _ scene:
            SceneModel
    ) {

        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        scene
                            .restorationSnapshot()
                    ),
            let json =
                String(
                    data:
                        data,
                    encoding:
                        .utf8
                )
        else {

            return
        }


        restorationJSON =
            json
    }
}

#endif
