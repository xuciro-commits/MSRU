//
//  RouteDestination.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Route Destination

/// Resolves a semantic application route into a workspace presentation.
///
/// Exact destinations usually need only presentation context.
///
/// Pattern destinations also receive the matched route itself so
/// associated route values remain available to the workspace.
///
/// Examples:
///
///     .library
///
///     .album(id)
///
///     .reservation(id)
///
@MainActor
public struct RouteDestination<Route, Context>
where
    Route:
        Hashable & Sendable {

    public let id:
        String


    private let matchesRoute:
        (Route) -> Bool


    private let buildWorkspace:
        (
            Route,
            Context
        ) -> WorkspacePresentation<Context>


    // MARK: - Exact Workspace

    public init(
        id:
            String,
        route:
            Route,
        workspace:
            @escaping (
                Context
            ) -> WorkspacePresentation<Context>
    ) {

        self.id =
            id


        self.matchesRoute = {
            candidate in

            candidate
            ==
            route
        }


        self.buildWorkspace = {
            _,
            context in

            workspace(
                context
            )
        }
    }


    // MARK: - Pattern Workspace

    public init(
        id:
            String,
        matches:
            @escaping (
                Route
            ) -> Bool,
        workspace:
            @escaping (
                Route,
                Context
            ) -> WorkspacePresentation<Context>
    ) {

        self.id =
            id

        self.matchesRoute =
            matches

        self.buildWorkspace =
            workspace
    }


    // MARK: - Exact View Compatibility

    /// Incremental compatibility for existing destinations
    /// that still produce only primary workspace content.
    public init<Content: View>(
        id:
            String,
        route:
            Route,
        @ViewBuilder content:
            @escaping (
                Context
            ) -> Content
    ) {

        self.init(
            id:
                id,
            route:
                route,
            workspace: {
                context in

                WorkspacePresentation {
                    _ in

                    content(
                        context
                    )
                }
            }
        )
    }


    // MARK: - Pattern View Compatibility

    /// Incremental compatibility for parameterized destinations.
    ///
    /// Both the matched route and presentation context remain available.
    public init<Content: View>(
        id:
            String,
        matches:
            @escaping (
                Route
            ) -> Bool,
        @ViewBuilder content:
            @escaping (
                Route,
                Context
            ) -> Content
    ) {

        self.init(
            id:
                id,
            matches:
                matches,
            workspace: {
                route,
                context in

                WorkspacePresentation {
                    _ in

                    content(
                        route,
                        context
                    )
                }
            }
        )
    }


    // MARK: - Matching

    public func matches(
        _ route:
            Route
    ) -> Bool {

        matchesRoute(
            route
        )
    }


    // MARK: - Resolution

    public func workspace(
        for route:
            Route,
        context:
            Context
    ) -> WorkspacePresentation<Context> {

        buildWorkspace(
            route,
            context
        )
    }
}
