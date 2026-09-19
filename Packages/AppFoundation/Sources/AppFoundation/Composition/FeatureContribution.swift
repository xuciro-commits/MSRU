//
//  FeatureContribution.swift
//  AppFoundation
//


// MARK: - Feature Contribution

/*
 FeatureContribution 是一个 Feature
 向 Application 声明的结构性能力。

 它表达：

     “我向 Application 提供什么”

 而不是：

     “Application 应该怎样画出来”


 第一阶段只建立最小语义核心。

 后续可以继续扩展：

 - sidebar
 - routes
 - commands
 - settings
 - search
 - inspector
 - toolbar

 但不让 Feature 直接返回 SwiftUI View。
 */

public struct FeatureContribution<Route>:
    Sendable
where
    Route:
        Hashable & Sendable {

    // MARK: - Sidebar

    public var sidebar:
        [SidebarContribution<Route>]


    // MARK: - Routes

    public var routes:
        [RouteContribution<Route>]


    // MARK: - Commands

    public var commands:
        [CommandContribution<Route>]


    // MARK: - Init

    public init(
        sidebar:
            [SidebarContribution<Route>] = [],
        routes:
            [RouteContribution<Route>] = [],
        commands:
            [CommandContribution<Route>] = []
    ) {

        self.sidebar =
            sidebar

        self.routes =
            routes

        self.commands =
            commands
    }
}
