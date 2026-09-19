//
//  ApplicationCompositionTests.swift
//  AppFoundationTests
//

import Testing

@testable import AppFoundation


// MARK: - Hotel Route

private enum HotelRoute:
    Hashable,
    Sendable {

    case rooms
    case guests
    case reservations
}


// MARK: - Rooms Feature

private enum RoomsFeature:
    ApplicationFeature {

    typealias Route =
        HotelRoute


    static let contributions:
        FeatureContribution<Route> =
            FeatureContribution(
                sidebar: [

                    SidebarContribution(
                        id:
                            "rooms",
                        group:
                            "hotel",
                        title:
                            "Rooms",
                        systemImage:
                            "bed.double",
                        route:
                            HotelRoute.rooms,
                        order:
                            10
                    )
                ],

                routes: [

                    RouteContribution(
                        id:
                            "rooms",
                        route:
                            HotelRoute.rooms
                    )
                ],

                commands: [

                    CommandContribution(
                        id:
                            "open-rooms",
                        title:
                            "Open Rooms",
                        route:
                            HotelRoute.rooms
                    )
                ]
            )
}


// MARK: - Guests Feature

private enum GuestsFeature:
    ApplicationFeature {

    typealias Route =
        HotelRoute


    static let contributions:
        FeatureContribution<Route> =
            FeatureContribution(
                sidebar: [

                    SidebarContribution(
                        id:
                            "guests",
                        group:
                            "hotel",
                        title:
                            "Guests",
                        systemImage:
                            "person.2",
                        route:
                            HotelRoute.guests,
                        order:
                            20
                    )
                ],

                routes: [

                    RouteContribution(
                        id:
                            "guests",
                        route:
                            HotelRoute.guests
                    )
                ]
            )
}


// MARK: - Application Composition Tests

struct ApplicationCompositionTests {

    @Test
    func featurePackCombinesIndependentFeatures() {

        var builder =
            FeaturePackBuilder<HotelRoute>()


        builder.add(
            RoomsFeature.self
        )


        builder.add(
            GuestsFeature.self
        )


        let pack =
            builder.build()


        #expect(
            pack.sidebar.map(\.route)
            ==
            [
                HotelRoute.rooms,
                HotelRoute.guests
            ]
        )


        #expect(
            pack.routes.map(\.route)
            ==
            [
                HotelRoute.rooms,
                HotelRoute.guests
            ]
        )


        #expect(
            pack.commands.count
            ==
            1
        )
    }
}
