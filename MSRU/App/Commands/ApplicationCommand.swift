//
//  ApplicationCommand.swift
//  MSRU
//


// MARK: - Application Command

/*
 ApplicationCommand 描述：

 “调用者希望整个 Application 做什么”

 它位于 SceneCommand 之上。

 ApplicationCommand
        │
        ├── 选择 / 创建 Scene
        │
        └── 把 Scene-level intent
            继续下发为 SceneCommand


 当前层级：

 External / System / UI
          │
          ▼
 ApplicationCommand
          │
          ▼
 Application Command Runtime
          │
          ▼
 SceneRoutingRequest
          │
          ▼
 SceneCommand
          │
          ▼
 SceneModel


 Command 是瞬时 Intent。

 它不是：

 - persisted state
 - restoration snapshot
 - URL representation
 - SwiftUI NavigationPath
 - AppKit Window command

 因此 ApplicationCommand 本身不 Codable。
 */

nonisolated enum ApplicationCommand:
    Equatable,
    Sendable {

    // MARK: Route

    /*
     在某个 Scene 中打开 semantic route。

     “去哪里”
         由 SceneRoute 表达。

     “在哪个 Scene”
         由 SceneRoutingTarget 表达。

     Application 层不再复制这一套 target 语义。
     */

    case route(
        SceneRoutingRequest
    )


    // MARK: New Scene

    /*
     明确创建一个新的 Scene。

     route == nil
         创建默认 Scene。

     route != nil
         创建 Scene 后立即进入该 semantic route。
     */

    case openNewScene(
        route:
            SceneRoute?
    )


    // MARK: Activate Scene

    /*
     激活已经存在的 Scene。

     如果 Scene 已不存在，
     handler 必须返回 structured rejection，
     不偷偷创建 replacement。
     */

    case activateScene(
        SceneID
    )
}


// MARK: - Convenience Construction

extension ApplicationCommand {

    /*
     常用 external navigation shorthand。

     保留 SceneRoutingRequest 作为真正的 routing contract，
     这里只减少调用层样板代码。
     */

    static func open(
        _ route:
            SceneRoute,
        target:
            SceneRoutingTarget =
                .activeOrNew
    ) -> Self {

        .route(
            SceneRoutingRequest(
                route:
                    route,
                target:
                    target
            )
        )
    }


    static var newScene:
        Self {

        .openNewScene(
            route:
                nil
        )
    }
}
