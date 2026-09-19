//
//  SingleSceneApplicationCommandHandler.swift
//  MSRU
//


// MARK: - Single Scene Application Command Handler

/*
 SingleSceneApplicationCommandHandler 描述一种
 application hosting capability：

 “当前 host 只有一个可寻址 Scene runtime”


 它不是：

 - iPad handler
 - SwiftUI handler
 - UIKit handler


 所以未来任何 single-scene host
 都可以直接复用。


 它只解释：

 ApplicationCommand
        ↓
 当前 single Scene 能不能完成


 SceneRoute 本身在这里是 opaque payload。

 Handler 不检查：

 - section
 - feature
 - screen
 - domain model
 */

@MainActor
final class SingleSceneApplicationCommandHandler:
    ApplicationCommandHandler {

    // MARK: - Scene

    private weak var scene:
        (any ApplicationSceneRuntime)?


    // MARK: - Attachment

    var sceneID:
        SceneID? {

        scene?
            .id
    }


    var isAttached:
        Bool {

        scene != nil
    }


    func attach(
        _ scene:
            any ApplicationSceneRuntime
    ) {

        self.scene =
            scene
    }


    func detach() {

        scene =
            nil
    }


    // MARK: - Handle

    func handle(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        guard
            let scene
        else {

            return
                .rejected(
                    .runtimeUnavailable
                )
        }


        switch command {

        // MARK: Route

        case .route(
            let request
        ):

            return
                handleRoute(
                    request,
                    scene:
                        scene
                )


        // MARK: Open New Scene

        case .openNewScene:

            /*
             Single Scene Runtime 没有
             scene creation capability。

             这是 hosting capability 的限制，
             不是某个平台的限制。

             MultiScene Runtime 会实现这个 command。
             */

            return
                .rejected(
                    .unsupported
                )


        // MARK: Activate Scene

        case .activateScene(
            let sceneID
        ):

            guard
                scene.id
                ==
                sceneID
            else {

                return
                    .rejected(
                        .sceneNotFound(
                            sceneID
                        )
                    )
            }


            /*
             对 single-scene host：

             唯一 attached Scene
             已经是当前 runtime。

             因此 activation 是 semantic no-op，
             但 command 已成功满足。
             */

            return
                .scene(
                    scene.id
                )
        }
    }


    // MARK: - Route

    private func handleRoute(
        _ request:
            SceneRoutingRequest,
        scene:
            any ApplicationSceneRuntime
    ) -> ApplicationCommandResult {

        switch request.target {

        // MARK: Active Or New

        case .activeOrNew:

            scene
                .send(
                    .navigate(
                        request.route
                    )
                )

            return
                .scene(
                    scene.id
                )


        // MARK: Explicit Scene

        case .scene(
            let requestedSceneID
        ):

            guard
                requestedSceneID
                ==
                scene.id
            else {

                return
                    .rejected(
                        .sceneNotFound(
                            requestedSceneID
                        )
                    )
            }


            scene
                .send(
                    .navigate(
                        request.route
                    )
                )


            return
                .scene(
                    scene.id
                )


        // MARK: New Scene

        case .new:

            /*
             创建第二个 Scene
             超出了 SingleScene Runtime capability。
             */

            return
                .rejected(
                    .unsupported
                )
        }
    }
}
