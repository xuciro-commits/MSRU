//
//  RouteContribution.swift
//  AppFoundation
//


// MARK: - Route Contribution

/*
 RouteContribution 不是 Router。

 它只是在 Application Composition
 中声明：

     “这个 Feature 拥有这个 Route”


 后续真正的 destination rendering
 会属于 UI / Host adapter。
 */

public struct RouteContribution<Route>:
    Identifiable,
    Hashable,
    Sendable
where
    Route:
        Hashable & Sendable {

    public let id:
        String


    public let route:
        Route


    public init(
        id:
            String,
        route:
            Route
    ) {

        self.id =
            id

        self.route =
            route
    }
}
