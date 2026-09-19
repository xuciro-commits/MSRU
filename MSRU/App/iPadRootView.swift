#if os(iOS)

import SwiftUI


struct iPadRootView:
    View {

    // MARK: - Application

    let application:
        ApplicationModel


    // MARK: - Platform Restoration

    /*
     @SceneStorage 本身就是 per-scene。

     这里只保存轻量 JSON String。

     Runtime object graph 不进入 SceneStorage。
     */

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


    // MARK: - Bootstrap

    @MainActor
    private func restoreOrCreateScene() {

        guard
            scene == nil
        else {

            return
        }


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

            scene =
                restoredScene


            return
        }


        let newScene =
            SceneModel(
                application:
                    application
            )


        scene =
            newScene


        persist(
            newScene
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
