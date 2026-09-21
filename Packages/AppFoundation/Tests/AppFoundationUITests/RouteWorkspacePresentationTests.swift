//
//  RouteWorkspacePresentationTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing
import AppFoundation
@testable import AppFoundationUI

private enum WorkspaceRoute: Hashable, Sendable {
    case library
    case item(Int)
}

private struct WorkspaceRouteContext {
    let title: String
    let count: Int
}

private enum HotelRoute: Hashable, Sendable {
    case rooms
    case guests
    case room(Int)
}

private struct HotelContext {}

private enum RoomsFeature: ApplicationFeaturePresentation {
    typealias Route = HotelRoute
    typealias PresentationContext = HotelContext

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            routes: [
                RouteContribution(id: "rooms", route: .rooms)
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(id: "rooms", route: HotelRoute.rooms) { _ in
                Text("Rooms")
            },
            RouteDestination(
                id: "room-detail",
                matches: { route in
                    if case .room = route { return true }
                    return false
                }
            ) { route, _ in
                Text(String(describing: route))
            }
        ]
    }
}

struct RouteWorkspacePresentationTests {

    @Test
    @MainActor
    func exactRouteBuildsWorkspacePresentation() {
        let destination = RouteDestination<WorkspaceRoute, WorkspaceRouteContext>(
            id: "library",
            route: .library,
            workspace: { context in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: context.title,
                        subtitle: "\(context.count) items"
                    )
                ) { _ in
                    Text("Library")
                }
            }
        )

        let workspace = destination.workspace(
            for: .library,
            context: WorkspaceRouteContext(title: "Library", count: 12)
        )

        #expect(workspace.identity?.title == "Library")
        #expect(workspace.identity?.subtitle == "12 items")
    }

    @Test
    @MainActor
    func patternRouteBuildsWorkspacePresentation() {
        let destination = RouteDestination<WorkspaceRoute, WorkspaceRouteContext>(
            id: "item",
            matches: { route in
                if case .item = route { return true }
                return false
            },
            workspace: { _, context in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(title: context.title)
                ) { _ in
                    Text("Item")
                }
            }
        )

        #expect(destination.matches(.item(42)))

        let workspace = destination.workspace(
            for: .item(42),
            context: WorkspaceRouteContext(title: "Selected Item", count: 1)
        )

        #expect(workspace.identity?.title == "Selected Item")
    }

    @Test
    @MainActor
    func legacyViewDestinationIsWrappedAsWorkspace() {
        let destination = RouteDestination<WorkspaceRoute, WorkspaceRouteContext>(
            id: "legacy",
            route: .library
        ) { context in
            Text(context.title)
        }

        let workspace = destination.workspace(
            for: .library,
            context: WorkspaceRouteContext(title: "Legacy Library", count: 10)
        )

        #expect(workspace.identity == nil)
        #expect(workspace.context == nil)
        #expect(workspace.workspaceAccessory == nil)
    }

    @Test
    @MainActor
    func presentationPackResolvesWorkspaceWithoutShellKnowingRoutes() {
        var pack = FeaturePresentationPack<WorkspaceRoute, WorkspaceRouteContext>()
        pack.append(
            contentsOf: [
                RouteDestination(
                    id: "library",
                    route: WorkspaceRoute.library,
                    workspace: { context in
                        WorkspacePresentation(
                            identity: WorkspaceIdentity(title: context.title)
                        ) { _ in
                            Text("Library")
                        }
                    }
                )
            ]
        )

        let workspace = pack.workspace(
            for: .library,
            context: WorkspaceRouteContext(title: "Resolved Library", count: 4)
        )

        #expect(workspace?.identity?.title == "Resolved Library")
    }

    @Test
    @MainActor
    func exactDestinationMatchesExactRoute() {
        let destination = RoomsFeature.routeDestinations[0]
        #expect(destination.matches(.rooms))
        #expect(!destination.matches(.guests))
    }

    @Test
    @MainActor
    func patternDestinationSupportsParameterizedRoutes() {
        let destination = RoomsFeature.routeDestinations[1]
        #expect(destination.matches(.room(301)))
        #expect(!destination.matches(.rooms))
    }

    @Test
    @MainActor
    func presentationPackCombinesFeatureDestinations() {
        var builder = FeaturePresentationPackBuilder<HotelRoute, HotelContext>()
        builder.add(RoomsFeature.self)
        let pack = builder.build()

        #expect(pack.routeDestinations.map(\.id) == ["rooms", "room-detail"])
    }
}
