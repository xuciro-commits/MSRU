//
//  FeaturePack.swift
//  AppFoundation
//


// MARK: - Feature Pack

public struct FeaturePack<Route>:
    Sendable
where
    Route:
        Hashable & Sendable {

    // MARK: - Contributions

    public private(set) var sidebar:
        [SidebarContribution<Route>]


    public private(set) var routes:
        [RouteContribution<Route>]


    public private(set) var commands:
        [CommandContribution<Route>]


    // MARK: - Init

    public init() {

        self.sidebar = []
        self.routes = []
        self.commands = []
    }


    // MARK: - Append

    public mutating func append(
        _ contribution:
            FeatureContribution<Route>
    ) {

        sidebar.append(
            contentsOf:
                contribution.sidebar
        )


        routes.append(
            contentsOf:
                contribution.routes
        )


        commands.append(
            contentsOf:
                contribution.commands
        )
    }


    // MARK: - Normalize

    public mutating func normalize() {

        sidebar.sort {

            if $0.group == $1.group {

                return $0.order
                    < $1.order
            }

            return ($0.group ?? "")
                < ($1.group ?? "")
        }
    }
}
