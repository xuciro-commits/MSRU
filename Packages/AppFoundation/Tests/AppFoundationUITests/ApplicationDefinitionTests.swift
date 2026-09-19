//
//  ApplicationDefinitionTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing
import AppFoundation

@testable import AppFoundationUI


private enum DemoRoute:
    Hashable,
    Sendable {

    case rooms
    case guests
    case settings
}


private struct DemoContext {}


// MARK: - Rooms Feature

private enum RoomsFeature:
    ApplicationFeaturePresentation {

    typealias Route =
        DemoRoute

    typealias PresentationContext =
        DemoContext


    nonisolated static var contributions:
        FeatureContribution<Route> {

        FeatureContribution(
            sidebar: [

                SidebarContribution(
                    id:
                        "rooms",
                    group:
                        "Hotel",
                    title:
                        "Rooms",
                    systemImage:
                        "bed.double",
                    route:
                        .rooms,
                    order:
                        10
                )
            ],

            routes: [

                RouteContribution(
                    id:
                        "rooms",
                    route:
                        .rooms
                )
            ]
        )
    }


    @MainActor
    static var routeDestinations:
        [
            RouteDestination<
                Route,
                PresentationContext
            >
        ] {

        [

            RouteDestination(
                id:
                    "rooms",
                route:
                    DemoRoute.rooms
            ) {
                _ in

                Text(
                    "Rooms"
                )
            }
        ]
    }
}


// MARK: - Tests

struct ApplicationDefinitionTests {

    @Test
    @MainActor
    func oneFeatureRegistrationInstallsStructureAndPresentation() {

        var builder =
            ApplicationDefinitionBuilder<
                DemoRoute,
                DemoContext
            >()


        builder.add(
            RoomsFeature.self
        )


        let definition =
            builder.build()


        #expect(
            definition
                .sidebar
                .map(\.id)
            ==
            [
                "rooms"
            ]
        )


        #expect(
            definition
                .routes
                .map(\.id)
            ==
            [
                "rooms"
            ]
        )


        #expect(
            definition
                .routeDestinations
                .map(\.id)
            ==
            [
                "rooms"
            ]
        )
    }


    @Test
    @MainActor
    func hostContributionJoinsSameDefinition() {

        var builder =
            ApplicationDefinitionBuilder<
                DemoRoute,
                DemoContext
            >()


        builder.add(
            RoomsFeature.self
        )


        builder.addHost(
            contribution:
                FeatureContribution(
                    routes: [

                        RouteContribution(
                            id:
                                "settings",
                            route:
                                DemoRoute.settings
                        )
                    ]
                ),
            routeDestinations: [

                RouteDestination(
                    id:
                        "settings",
                    route:
                        DemoRoute.settings
                ) {
                    _ in

                    Text(
                        "Settings"
                    )
                }
            ]
        )


        let definition =
            builder.build()


        #expect(
            definition
                .routes
                .map(\.id)
            ==
            [
                "rooms",
                "settings"
            ]
        )


        #expect(
            definition
                .routeDestinations
                .map(\.id)
            ==
            [
                "rooms",
                "settings"
            ]
        )
    }
}
