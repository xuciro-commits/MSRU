#if os(iOS) || os(visionOS)

import Foundation
import SwiftUI
import AppFoundationUI


@MainActor
struct SwiftUISceneRootView:
    View {

    // MARK: - Application

    let application:
        ApplicationModel


    // MARK: - External Command Source

    private let externalURLSource =
        SceneRouteURLCommandSource(
            scheme:
                "msru"
        )


    // MARK: - Command Runtime

    @State
    private var commandRuntime:
        SingleSceneApplicationCommandRuntime


    // MARK: - Lifecycle Runtime

    @State
    private var lifecycleRuntime:
        ApplicationLifecycleRuntime


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


    @State private var shellSession: MSRUApplicationShellSession?

    // MARK: - Init

    init(
        application:
            ApplicationModel
    ) {

        self.application =
            application


        let commandRuntime =
            SingleSceneApplicationCommandRuntime()


        _commandRuntime =
            State(
                initialValue:
                    commandRuntime
            )


        _lifecycleRuntime =
            State(
                initialValue:
                    ApplicationLifecycleRuntime(
                        commandRuntime:
                            commandRuntime
                    )
            )
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
            }
        }
        .task {

            bootstrapIfNeeded()
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

        Group {
            if let shellSession {
                SwiftUIApplicationShell(
                    shell: shellSession.resolve(),
                    isContextPresented: Binding(get: { scene.isQueuePresented }, set: { scene.isQueuePresented = $0 })
                ) {
                    SidebarPaneView(scene: scene)
                }
            }
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

    private func handleExternalURL(
        _ url:
            URL
    ) {

        guard
            let command =
                externalURLSource
                    .command(
                        from:
                            url
                    )
        else {

            return
        }


        commandRuntime
            .send(
                command
            )
    }


    // MARK: - Bootstrap

    private func bootstrapIfNeeded() {

        guard
            lifecycleRuntime.phase
            ==
            .initialized
        else {

            return
        }


        lifecycleRuntime
            .beginBootstrap()


        /*
         Application Scope startup。

         idempotency 属于 ApplicationModel。
         */

        application
            .start()


        let resolvedScene =
            restoreOrCreateScene()


        scene =
            resolvedScene

        let session = MSRUApplicationShellSession(scene: resolvedScene)
        session.installShellActions { [weak resolvedScene] in
            resolvedScene?.isQueuePresented.toggle()
        }
        shellSession = session


        /*
         Wiring。
         不自动 activate。
         */

        commandRuntime
            .attach(
                resolvedScene
            )


        /*
         Platform runtime 现在真正 ready。
         */

        lifecycleRuntime
            .markReady()


        /*
         markReady() 可能 flush
         bootstrap 前到达的 commands。

         所以 snapshot 必须在 flush 后保存。
         */

        persist(
            resolvedScene
        )
    }


    // MARK: - Restore / Create

    private func restoreOrCreateScene()
        -> SceneModel {

        if let restorationJSON,
           let data =
            restorationJSON
                .data(
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

            return
                restoredScene
        }


        return
            SceneModel(
                application:
                    application
            )
    }


    // MARK: - Persist

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

#Preview("iPad Application") {
    SwiftUISceneRootView(application: MSRUPreviewData.makeApplication())
}

#endif
