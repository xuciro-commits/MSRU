//
//  RouteDestinationTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing
import AppFoundation

@testable import AppFoundationUI


private enum HotelRoute:
    Hashable,
    Sendable {

    case rooms
    case guests
    case room(Int)
}


private struct HotelContext {}


private enum RoomsFeature:
    ApplicationFeaturePresentation {

    typealias Route =
        HotelRoute

    typealias PresentationContext =
        HotelContext


    nonisolated static var contributions:
        FeatureContribution<Route> {

        FeatureContribution(
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
                    HotelRoute.rooms
            ) {
                _ in

                Text(
                    "Rooms"
                )
            },


            RouteDestination(
                id:
                    "room-detail",
                matches: {
                    route in

                    if case .room =
                        route {

                        return true
                    }

                    return false
                }
            ) {
                route,
                _ in

                Text(
                    String(
                        describing:
                            route
                    )
                )
            }
        ]
    }
}


struct RouteDestinationTests {

    @Test
    @MainActor
    func exactDestinationMatchesExactRoute() {

        let destination =
            RoomsFeature
                .routeDestinations[0]


        #expect(
            destination.matches(
                .rooms
            )
        )


        #expect(
            !destination.matches(
                .guests
            )
        )
    }


    @Test
    @MainActor
    func patternDestinationSupportsParameterizedRoutes() {

        let destination =
            RoomsFeature
                .routeDestinations[1]


        #expect(
            destination.matches(
                .room(
                    301
                )
            )
        )


        #expect(
            !destination.matches(
                .rooms
            )
        )
    }


    @Test
    @MainActor
    func presentationPackCombinesFeatureDestinations() {

        var builder =
            FeaturePresentationPackBuilder<
                HotelRoute,
                HotelContext
            >()


        builder.add(
            RoomsFeature.self
        )


        let pack =
            builder.build()


        #expect(
            pack
                .routeDestinations
                .map(\.id)
            ==
            [
                "rooms",
                "room-detail"
            ]
        )
    }
}
