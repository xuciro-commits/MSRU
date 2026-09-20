//
//  SidebarContribution.swift
//  AppFoundation
//


// MARK: - Sidebar Contribution

public struct SidebarContribution<Route>:
    Identifiable,
    Hashable,
    Sendable
where
    Route:
        Hashable & Sendable {

    public let id:
        String


    public let group:
        String?


    public let title:
        String


    public let systemImage:
        String


    public let route:
        Route


    public let order:
        Int


    public let badge:
        String?


    public init(
        id:
            String,
        group:
            String? = nil,
        title:
            String,
        systemImage:
            String,
        route:
            Route,
        order:
            Int = 0,
        badge:
            String? = nil
    ) {

        self.id =
            id

        self.group =
            group

        self.title =
            title

        self.systemImage =
            systemImage

        self.route =
            route

        self.order =
            order

        self.badge =
            badge
    }
}
