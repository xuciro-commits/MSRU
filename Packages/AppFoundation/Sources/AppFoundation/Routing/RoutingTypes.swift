//
//  RoutingTypes.swift
//  AppFoundation
//

import Foundation

// MARK: - Scene ID

public struct SceneID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue.uuidString
    }
}

// MARK: - Scene Routing Target

public enum SceneRoutingTarget: Equatable, Hashable, Sendable {
    case activeOrNew
    case new
    case scene(SceneID)
}

// MARK: - Scene Routing Request

public struct SceneRoutingRequest<Route>: Equatable, Hashable, Sendable where Route: Hashable & Sendable {
    public let route: Route
    public let target: SceneRoutingTarget

    public init(route: Route, target: SceneRoutingTarget = .activeOrNew) {
        self.route = route
        self.target = target
    }
}

// MARK: - Scene Command

public enum SceneCommand<Route>: Equatable, Hashable, Sendable where Route: Hashable & Sendable {
    case navigate(Route)
}

// MARK: - Application Command

public enum ApplicationCommand<Route>: Equatable, Hashable, Sendable where Route: Hashable & Sendable {
    case route(SceneRoutingRequest<Route>)
    case openNewScene(route: Route?)
    case activateScene(SceneID)

    public static func open(
        _ route: Route,
        target: SceneRoutingTarget = .activeOrNew
    ) -> Self {
        .route(SceneRoutingRequest(route: route, target: target))
    }

    public static var newScene: Self {
        .openNewScene(route: nil)
    }
}
