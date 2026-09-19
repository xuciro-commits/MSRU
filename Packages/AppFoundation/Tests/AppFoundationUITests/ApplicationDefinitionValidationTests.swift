//
//  ApplicationDefinitionValidationTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing
import AppFoundation

@testable import AppFoundationUI


private enum ValidationRoute:
    Hashable,
    Sendable {

    case home
    case library
    case settings
}


private struct ValidationContext {}


// MARK: - Tests

struct ApplicationDefinitionValidationTests {

    @Test
    @MainActor
    func validDefinitionPassesValidation() {

        var definition =
            ApplicationDefinition<
                ValidationRoute,
                ValidationContext
            >()


        definition.append(
            contribution:
                FeatureContribution(
                    routes: [

                        RouteContribution(
                            id:
                                "home",
                            route:
                                .home
                        )
                    ]
                ),
            routeDestinations: [

                RouteDestination(
                    id:
                        "home",
                    route:
                        ValidationRoute.home
                ) {
                    _ in

                    Text(
                        "Home"
                    )
                }
            ]
        )


        let report =
            definition.validate()


        #expect(
            report.isValid
        )
    }


    @Test
    @MainActor
    func routeWithoutDestinationIsDetected() {

        var definition =
            ApplicationDefinition<
                ValidationRoute,
                ValidationContext
            >()


        definition.append(
            contribution:
                FeatureContribution(
                    routes: [

                        RouteContribution(
                            id:
                                "library",
                            route:
                                .library
                        )
                    ]
                ),
            routeDestinations:
                []
        )


        let report =
            definition.validate()


        #expect(
            report.issues.contains(
                .routeWithoutDestination(
                    routeID:
                        "library",
                    route:
                        .library
                )
            )
        )
    }


    @Test
    @MainActor
    func destinationWithoutDeclaredRouteIsDetected() {

        var definition =
            ApplicationDefinition<
                ValidationRoute,
                ValidationContext
            >()


        definition.append(
            contribution:
                FeatureContribution(),
            routeDestinations: [

                RouteDestination(
                    id:
                        "settings",
                    route:
                        ValidationRoute.settings
                ) {
                    _ in

                    Text(
                        "Settings"
                    )
                }
            ]
        )


        let report =
            definition.validate()


        #expect(
            report.issues.contains(
                .destinationWithoutDeclaredRoute(
                    destinationID:
                        "settings"
                )
            )
        )
    }


    @Test
    @MainActor
    func multipleDestinationsForSameRouteAreDetected() {

        var definition =
            ApplicationDefinition<
                ValidationRoute,
                ValidationContext
            >()


        definition.append(
            contribution:
                FeatureContribution(
                    routes: [

                        RouteContribution(
                            id:
                                "home",
                            route:
                                .home
                        )
                    ]
                ),
            routeDestinations: [

                RouteDestination(
                    id:
                        "home-a",
                    route:
                        ValidationRoute.home
                ) {
                    _ in

                    Text(
                        "Home A"
                    )
                },


                RouteDestination(
                    id:
                        "home-b",
                    route:
                        ValidationRoute.home
                ) {
                    _ in

                    Text(
                        "Home B"
                    )
                }
            ]
        )


        let report =
            definition.validate()


        #expect(
            report.issues.contains(
                .routeMatchedByMultipleDestinations(
                    routeID:
                        "home",
                    route:
                        .home,
                    destinationIDs:
                        [
                            "home-a",
                            "home-b"
                        ]
                )
            )
        )
    }


    @Test
    @MainActor
    func duplicateDestinationIDsAreDetected() {

        var definition =
            ApplicationDefinition<
                ValidationRoute,
                ValidationContext
            >()


        definition.append(
            contribution:
                FeatureContribution(
                    routes: [

                        RouteContribution(
                            id:
                                "home",
                            route:
                                .home
                        ),

                        RouteContribution(
                            id:
                                "library",
                            route:
                                .library
                        )
                    ]
                ),
            routeDestinations: [

                RouteDestination(
                    id:
                        "page",
                    route:
                        ValidationRoute.home
                ) {
                    _ in

                    Text(
                        "Home"
                    )
                },


                RouteDestination(
                    id:
                        "page",
                    route:
                        ValidationRoute.library
                ) {
                    _ in

                    Text(
                        "Library"
                    )
                }
            ]
        )


        let report =
            definition.validate()


        #expect(
            report.issues.contains(
                .duplicateDestinationID(
                    "page"
                )
            )
        )
    }
}
