//
//  SceneRoutingRequest.swift
//  AppFoundation
//


// MARK: - Scene Routing Request

/*
 Route：

     去哪里

 Target：

     在哪个 Scene 中打开


 AppFoundation 对 Route 的唯一要求：

 - Hashable
 - Sendable


 不要求 Codable。

 因为：

 Routing Capability
 !=
 Restoration Capability

 只有真正需要 restoration 的 Host
 才应该额外要求自己的 Route Codable。
 */

public struct SceneRoutingRequest<Route>:
    Equatable,
    Hashable,
    Sendable
where
    Route:
        Hashable & Sendable {

    // MARK: - Route

    public let route:
        Route


    // MARK: - Target

    public let target:
        SceneRoutingTarget


    // MARK: - Init

    public init(
        route:
            Route,
        target:
            SceneRoutingTarget = .activeOrNew
    ) {

        self.route =
            route


        self.target =
            target
    }
}
