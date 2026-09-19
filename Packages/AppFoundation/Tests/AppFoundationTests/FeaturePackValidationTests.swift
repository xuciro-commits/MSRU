//
//  FeaturePackValidationTests.swift
//  AppFoundationTests
//

import Testing

@testable import AppFoundation


private enum ValidationRoute:
    Hashable,
    Sendable {

    case home
    case library
    case settings
}


struct FeaturePackValidationTests {

    @Test
    func validFeaturePackPassesValidation() {

        var pack =
            FeaturePack<ValidationRoute>()


        pack.append(
            FeatureContribution(
                sidebar: [

                    SidebarContribution(
                        id:
                            "home",
                        group:
                            "Main",
                        title:
                            "Home",
                        systemImage:
                            "house",
                        route:
                            .home,
                        order:
                            10
                    )
                ],

                routes: [

                    RouteContribution(
                        id:
                            "home",
                        route:
                            .home
                    )
                ]
            )
        )


        let report =
            pack.validate()


        #expect(
            report.isValid
        )

        #expect(
            report.issues.isEmpty
        )
    }


    @Test
    func duplicateIDsAreDetected() {

        var pack =
            FeaturePack<ValidationRoute>()


        pack.append(
            FeatureContribution(
                sidebar: [

                    SidebarContribution(
                        id:
                            "duplicate",
                        group:
                            nil,
                        title:
                            "Home",
                        systemImage:
                            "house",
                        route:
                            .home,
                        order:
                            10
                    ),

                    SidebarContribution(
                        id:
                            "duplicate",
                        group:
                            nil,
                        title:
                            "Library",
                        systemImage:
                            "books.vertical",
                        route:
                            .library,
                        order:
                            20
                    )
                ],

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
            )
        )


        let report =
            pack.validate()


        #expect(
            report.issues.contains(
                .duplicateSidebarID(
                    "duplicate"
                )
            )
        )
    }


    @Test
    func duplicateRouteOwnershipIsDetected() {

        var pack =
            FeaturePack<ValidationRoute>()


        pack.append(
            FeatureContribution(
                routes: [

                    RouteContribution(
                        id:
                            "library-a",
                        route:
                            .library
                    ),

                    RouteContribution(
                        id:
                            "library-b",
                        route:
                            .library
                    )
                ]
            )
        )


        let report =
            pack.validate()


        #expect(
            report.issues.contains(
                .routeClaimedMultipleTimes(
                    route:
                        .library,
                    contributionIDs:
                        [
                            "library-a",
                            "library-b"
                        ]
                )
            )
        )
    }


    @Test
    func sidebarCannotReferenceUndeclaredRoute() {

        var pack =
            FeaturePack<ValidationRoute>()


        pack.append(
            FeatureContribution(
                sidebar: [

                    SidebarContribution(
                        id:
                            "library",
                        group:
                            nil,
                        title:
                            "Library",
                        systemImage:
                            "books.vertical",
                        route:
                            .library,
                        order:
                            10
                    )
                ]
            )
        )


        let report =
            pack.validate()


        #expect(
            report.issues.contains(
                .sidebarRouteNotDeclared(
                    sidebarID:
                        "library",
                    route:
                        .library
                )
            )
        )
    }
}
