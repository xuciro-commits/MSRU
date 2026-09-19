//
//  FeaturePresentationPack.swift
//  AppFoundationUI
//

import AppFoundation


@MainActor
public struct FeaturePresentationPack<Route, Context>
where
    Route: Hashable & Sendable {

    public private(set) var routeDestinations:
        [
            RouteDestination<
                Route,
                Context
            >
        ]


    public init() {

        self.routeDestinations =
            []
    }


    public mutating func append(
        contentsOf destinations:
            [
                RouteDestination<
                    Route,
                    Context
                >
            ]
    ) {

        routeDestinations
            .append(
                contentsOf:
                    destinations
            )
    }
}
