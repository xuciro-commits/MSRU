//
//  RoutingCoreTests.swift
//  AppFoundationTests
//

import Testing

@testable import AppFoundation


// MARK: - Hotel Fixture

private enum HotelRoute:
    Hashable,
    Sendable {

    case dashboard

    case room(
        Int
    )

    case reservation(
        Int
    )
}


// MARK: - Inventory Fixture

private enum InventoryRoute:
    Hashable,
    Sendable {

    case dashboard

    case product(
        String
    )

    case supplier(
        String
    )
}


// MARK: - Routing Core Tests

struct RoutingCoreTests {

    // MARK: - Route Type

    @Test
    func routingRequestPreservesHostRouteType() {

        let request =
            SceneRoutingRequest(
                route:
                    HotelRoute.room(
                        204
                    )
            )


        #expect(
            request.route
            ==
            .room(
                204
            )
        )


        #expect(
            request.target
            ==
            .activeOrNew
        )
    }


    // MARK: - Explicit Target

    @Test
    func routingRequestPreservesSceneTarget() {

        let sceneID =
            SceneID()


        let request =
            SceneRoutingRequest(
                route:
                    InventoryRoute.product(
                        "SKU-100"
                    ),
                target:
                    .scene(
                        sceneID
                    )
            )


        #expect(
            request.target
            ==
            .scene(
                sceneID
            )
        )
    }


    // MARK: - Application Command

    @Test
    func applicationCommandCarriesTypedRoute() {

        let command:
            ApplicationCommand<HotelRoute> =
                .open(
                    .reservation(
                        9001
                    ),
                    target:
                        .new
                )


        #expect(
            command
            ==
            .route(
                SceneRoutingRequest(
                    route:
                        .reservation(
                            9001
                        ),
                    target:
                        .new
                )
            )
        )
    }


    // MARK: - Scene Command

    @Test
    func sceneCommandCarriesTypedRoute() {

        let command:
            SceneCommand<InventoryRoute> =
                .navigate(
                    .supplier(
                        "SUP-42"
                    )
                )


        #expect(
            command
            ==
            .navigate(
                .supplier(
                    "SUP-42"
                )
            )
        )
    }


    // MARK: - Product Independence

    @Test
    func differentApplicationsUseSameRoutingKernel() {

        let hotel:
            ApplicationCommand<HotelRoute> =
                .open(
                    .dashboard
                )


        let inventory:
            ApplicationCommand<InventoryRoute> =
                .open(
                    .dashboard
                )


        #expect(
            hotel
            ==
            .route(
                SceneRoutingRequest(
                    route:
                        HotelRoute.dashboard
                )
            )
        )


        #expect(
            inventory
            ==
            .route(
                SceneRoutingRequest(
                    route:
                        InventoryRoute.dashboard
                )
            )
        )
    }
}
