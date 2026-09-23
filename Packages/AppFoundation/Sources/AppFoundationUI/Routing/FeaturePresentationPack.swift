//
//  FeaturePresentationPack.swift
//  AppFoundationUI
//

import AppFoundation
import SwiftUI

// MARK: - Application Feature Presentation

public protocol ApplicationFeaturePresentation: ApplicationFeature {
    associatedtype PresentationContext

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] { get }
}

// MARK: - Route Destination

/// Resolves a semantic application route into a workspace presentation.
@MainActor
public struct RouteDestination<Route, Context> where Route: Hashable & Sendable {
    public let id: String
    private let matchesRoute: (Route) -> Bool
    private let buildWorkspace: (Route, Context) -> WorkspacePresentation<Context>

    // MARK: - Exact Workspace
    public init(
        id: String,
        route: Route,
        workspace: @escaping (Context) -> WorkspacePresentation<Context>
    ) {
        self.id = id
        self.matchesRoute = { candidate in candidate == route }
        self.buildWorkspace = { _, context in workspace(context) }
    }

    // MARK: - Pattern Workspace
    public init(
        id: String,
        matches: @escaping (Route) -> Bool,
        workspace: @escaping (Route, Context) -> WorkspacePresentation<Context>
    ) {
        self.id = id
        self.matchesRoute = matches
        self.buildWorkspace = workspace
    }

    // MARK: - Exact View Compatibility
    public init<Content: View>(
        id: String,
        route: Route,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        self.init(
            id: id,
            route: route,
            workspace: { context in
                WorkspacePresentation { _ in content(context) }
            }
        )
    }

    // MARK: - Pattern View Compatibility
    public init<Content: View>(
        id: String,
        matches: @escaping (Route) -> Bool,
        @ViewBuilder content: @escaping (Route, Context) -> Content
    ) {
        self.init(
            id: id,
            matches: matches,
            workspace: { route, context in
                WorkspacePresentation { _ in content(route, context) }
            }
        )
    }

    // MARK: - Matching & Resolution
    public func matches(_ route: Route) -> Bool {
        matchesRoute(route)
    }

    public func workspace(for route: Route, context: Context) -> WorkspacePresentation<Context> {
        buildWorkspace(route, context)
    }
}

// MARK: - Feature Presentation Pack

@MainActor
public struct FeaturePresentationPack<Route, Context> where Route: Hashable & Sendable {
    public private(set) var routeDestinations: [RouteDestination<Route, Context>]

    public init() {
        self.routeDestinations = []
    }

    public mutating func append(contentsOf destinations: [RouteDestination<Route, Context>]) {
        routeDestinations.append(contentsOf: destinations)
    }

    /// Resolves the first destination matching `route` into its workspace.
    public func workspace(
        for route: Route,
        context: Context
    ) -> WorkspacePresentation<Context>? {
        routeDestinations
            .first { $0.matches(route) }?
            .workspace(for: route, context: context)
    }
}

// MARK: - Feature Presentation Pack Builder

@MainActor
public struct FeaturePresentationPackBuilder<Route, Context> where Route: Hashable & Sendable {
    private var pack: FeaturePresentationPack<Route, Context>

    public init() {
        self.pack = FeaturePresentationPack()
    }

    @discardableResult
    public mutating func add<F>(_ feature: F.Type) -> Self
    where F: ApplicationFeaturePresentation, F.Route == Route, F.PresentationContext == Context {
        pack.append(contentsOf: F.routeDestinations)
        return self
    }

    public func build() -> FeaturePresentationPack<Route, Context> {
        pack
    }
}

// MARK: - Application Route View

/// Compatibility renderer from application routing into workspace content.
@MainActor
public struct ApplicationRouteView<Route, Context, Fallback>: View
where Route: Hashable & Sendable, Fallback: View {
    private let route: Route
    private let context: Context
    private let destinations: [RouteDestination<Route, Context>]
    private let fallback: (Route) -> Fallback

    public init(
        route: Route,
        context: Context,
        destinations: [RouteDestination<Route, Context>],
        @ViewBuilder fallback: @escaping (Route) -> Fallback
    ) {
        self.route = route
        self.context = context
        self.destinations = destinations
        self.fallback = fallback
    }

    public var body: some View {
        if let destination = destination {
            WorkspaceContentView(
                presentation: destination.workspace(for: route, context: context),
                context: context
            )
        } else {
            fallback(route)
        }
    }

    private var destination: RouteDestination<Route, Context>? {
        destinations.first { $0.matches(route) }
    }
}

#Preview("Application Route Fallback") {
    ApplicationRouteView(route: "preview", context: "Preview", destinations: []) { route in
        Text("No destination: \(route)")
    }
}
