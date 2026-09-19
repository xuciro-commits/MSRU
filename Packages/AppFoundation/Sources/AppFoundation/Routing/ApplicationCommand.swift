//
//  ApplicationCommand.swift
//  AppFoundation
//


// MARK: - Application Command

/*
 ApplicationCommand 描述整个 Application
 级别的 routing intent。


 SceneCommand：

     已知 Scene
     → Scene 内部做什么


 ApplicationCommand：

     整个 Application
     → 选择 / 创建 Scene
     → 然后执行 Route
 */

public enum ApplicationCommand<Route>:
    Equatable,
    Hashable,
    Sendable
where
    Route:
        Hashable & Sendable {

    // MARK: - Route

    case route(
        SceneRoutingRequest<Route>
    )


    // MARK: - New Scene

    case openNewScene(
        route:
            Route?
    )


    // MARK: - Activate Scene

    case activateScene(
        SceneID
    )
}


// MARK: - Convenience

public extension ApplicationCommand {

    static func open(
        _ route:
            Route,
        target:
            SceneRoutingTarget = .activeOrNew
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
