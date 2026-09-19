//
//  CommandContribution.swift
//  AppFoundation
//


// MARK: - Command Contribution

public struct CommandContribution<Route>:
    Identifiable,
    Hashable,
    Sendable
where
    Route:
        Hashable & Sendable {

    public let id:
        String


    public let title:
        String


    public let route:
        Route?


    public init(
        id:
            String,
        title:
            String,
        route:
            Route? = nil
    ) {

        self.id =
            id

        self.title =
            title

        self.route =
            route
    }
}
