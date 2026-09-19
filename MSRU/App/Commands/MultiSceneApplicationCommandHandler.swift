import AppFoundation

//
//  MultiSceneApplicationCommandHandler.swift
//  MSRU
//


// MARK: - Multi Scene Application Command Handler

/*
 MultiSceneApplicationCommandHandler
 将 ApplicationCommand 翻译成
 ApplicationMultiSceneRuntime capability。


 它不是：

 - macOS handler
 - Window coordinator
 - Scene registry
 - URL handler


 Command semantic:

 ApplicationCommand
        │
        ▼
 MultiSceneApplicationCommandHandler
        │
        ▼
 ApplicationMultiSceneRuntime


 SceneRoute 在这里仍然只是
 opaque semantic payload。
 */

@MainActor
final class MultiSceneApplicationCommandHandler:
    ApplicationCommandHandler {

    // MARK: - Runtime

    private let runtime:
        any ApplicationMultiSceneRuntime


    // MARK: - Init

    init(
        runtime:
            any ApplicationMultiSceneRuntime
    ) {

        self.runtime =
            runtime
    }


    // MARK: - Handle

    func handle(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        switch command {

        // MARK: Route

        case .route(
            let request
        ):

            return
                handleRoute(
                    request
                )


        // MARK: Open New Scene

        case .openNewScene(
            let route
        ):

            let sceneID =
                runtime
                    .openNewScene(
                        route:
                            route
                    )


            return
                .scene(
                    sceneID
                )


        // MARK: Activate Scene

        case .activateScene(
            let sceneID
        ):

            guard
                runtime
                    .activateScene(
                        sceneID
                    )
            else {

                return
                    .rejected(
                        .sceneNotFound(
                            sceneID
                        )
                    )
            }


            return
                .scene(
                    sceneID
                )
        }
    }


    // MARK: - Route

    private func handleRoute(
        _ request:
            SceneRoutingRequest
    ) -> ApplicationCommandResult {

        if let sceneID =
            runtime
                .route(
                    request
                ) {

            return
                .scene(
                    sceneID
                )
        }


        /*
         MultiScene runtime contract：

         .scene(id)
             可以因为目标不存在而失败。

         .activeOrNew / .new
             一个支持对应 capability 的 runtime
             应该能够完成。

         如果仍返回 nil，
         视为当前 runtime 不支持该操作。
         */

        switch request.target {

        case .scene(
            let sceneID
        ):

            return
                .rejected(
                    .sceneNotFound(
                        sceneID
                    )
                )


        case .activeOrNew,
             .new:

            return
                .rejected(
                    .unsupported
                )
        }
    }
}
