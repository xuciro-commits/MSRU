//
//  ApplicationDefinition.swift
//  AppFoundationUI
//

import AppFoundation


// MARK: - Application Definition

@MainActor
public struct ApplicationDefinition<Route, Context>
where
    Route:
        Hashable & Sendable {

    // MARK: - Structure

    public private(set) var featurePack:
        FeaturePack<Route>


    // MARK: - Presentation

    public private(set) var presentationPack:
        FeaturePresentationPack<
            Route,
            Context
        >


    // MARK: - Init

    public init() {

        self.featurePack =
            FeaturePack()

        self.presentationPack =
            FeaturePresentationPack()
    }


    // MARK: - Convenient Projections

    public var sidebar:
        [SidebarContribution<Route>] {

        featurePack.sidebar
    }


    public var routes:
        [RouteContribution<Route>] {

        featurePack.routes
    }


    public var commands:
        [CommandContribution<Route>] {

        featurePack.commands
    }


    public var routeDestinations:
        [
            RouteDestination<
                Route,
                Context
            >
        ] {

        presentationPack
            .routeDestinations
    }


    // MARK: - Append

    public mutating func append(
        contribution:
            FeatureContribution<Route>,
        routeDestinations:
            [
                RouteDestination<
                    Route,
                    Context
                >
            ]
    ) {

        featurePack
            .append(
                contribution
            )


        presentationPack
            .append(
                contentsOf:
                    routeDestinations
            )
    }


    // MARK: - Normalize

    public mutating func normalize() {

        featurePack
            .normalize()
    }
}
