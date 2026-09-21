//
//  FeatureComposition.swift
//  AppFoundation
//

import Foundation

// MARK: - Application Feature Protocol

public protocol ApplicationFeature {
    associatedtype Route: Hashable & Sendable
    static var contributions: FeatureContribution<Route> { get }
}

public extension ApplicationFeature {
    static var contributions: FeatureContribution<Route> {
        FeatureContribution()
    }
}

// MARK: - Contributions

public struct RouteContribution<Route>: Identifiable, Hashable, Sendable where Route: Hashable & Sendable {
    public let id: String
    public let route: Route

    public init(id: String, route: Route) {
        self.id = id
        self.route = route
    }
}

public struct SidebarContribution<Route>: Identifiable, Hashable, Sendable where Route: Hashable & Sendable {
    public let id: String
    public let group: String?
    public let title: String
    public let systemImage: String
    public let route: Route
    public let order: Int
    public let badge: String?

    public init(
        id: String,
        group: String? = nil,
        title: String,
        systemImage: String,
        route: Route,
        order: Int = 0,
        badge: String? = nil
    ) {
        self.id = id
        self.group = group
        self.title = title
        self.systemImage = systemImage
        self.route = route
        self.order = order
        self.badge = badge
    }
}

public struct CommandContribution<Route>: Identifiable, Hashable, Sendable where Route: Hashable & Sendable {
    public let id: String
    public let title: String
    public let route: Route?

    public init(id: String, title: String, route: Route? = nil) {
        self.id = id
        self.title = title
        self.route = route
    }
}

public struct FeatureContribution<Route>: Sendable where Route: Hashable & Sendable {
    public var sidebar: [SidebarContribution<Route>]
    public var routes: [RouteContribution<Route>]
    public var commands: [CommandContribution<Route>]

    public init(
        sidebar: [SidebarContribution<Route>] = [],
        routes: [RouteContribution<Route>] = [],
        commands: [CommandContribution<Route>] = []
    ) {
        self.sidebar = sidebar
        self.routes = routes
        self.commands = commands
    }
}

// MARK: - Feature Pack

public struct FeaturePack<Route>: Sendable where Route: Hashable & Sendable {
    public private(set) var sidebar: [SidebarContribution<Route>]
    public private(set) var routes: [RouteContribution<Route>]
    public private(set) var commands: [CommandContribution<Route>]

    public init() {
        self.sidebar = []
        self.routes = []
        self.commands = []
    }

    public mutating func append(_ contribution: FeatureContribution<Route>) {
        sidebar.append(contentsOf: contribution.sidebar)
        routes.append(contentsOf: contribution.routes)
        commands.append(contentsOf: contribution.commands)
    }

    public mutating func normalize() {
        sidebar.sort {
            if $0.group == $1.group {
                return $0.order < $1.order
            }
            return ($0.group ?? "") < ($1.group ?? "")
        }
    }
}

// MARK: - Feature Pack Builder

public struct FeaturePackBuilder<Route> where Route: Hashable & Sendable {
    private var pack: FeaturePack<Route>

    public init() {
        self.pack = FeaturePack()
    }

    @discardableResult
    public mutating func add<F>(_ feature: F.Type) -> Self
    where F: ApplicationFeature, F.Route == Route {
        pack.append(F.contributions)
        return self
    }

    public func build() -> FeaturePack<Route> {
        var result = pack
        result.normalize()
        return result
    }
}

// MARK: - Feature Pack Validation

public enum FeaturePackValidationIssue<Route>: Equatable, Sendable, CustomStringConvertible where Route: Hashable & Sendable {
    case duplicateSidebarID(String)
    case duplicateRouteID(String)
    case duplicateCommandID(String)
    case routeClaimedMultipleTimes(route: Route, contributionIDs: [String])
    case sidebarRouteNotDeclared(sidebarID: String, route: Route)
    case commandRouteNotDeclared(commandID: String, route: Route)

    public var description: String {
        switch self {
        case .duplicateSidebarID(let id):
            return "Duplicate sidebar contribution ID: \(id)"
        case .duplicateRouteID(let id):
            return "Duplicate route contribution ID: \(id)"
        case .duplicateCommandID(let id):
            return "Duplicate command contribution ID: \(id)"
        case .routeClaimedMultipleTimes(let route, let contributionIDs):
            return "Route is claimed multiple times: \(String(describing: route)) by \(contributionIDs.joined(separator: ", "))"
        case .sidebarRouteNotDeclared(let sidebarID, let route):
            return "Sidebar contribution '\(sidebarID)' points to undeclared route: \(String(describing: route))"
        case .commandRouteNotDeclared(let commandID, let route):
            return "Command contribution '\(commandID)' points to undeclared route: \(String(describing: route))"
        }
    }
}

public struct FeaturePackValidationReport<Route>: Sendable where Route: Hashable & Sendable {
    public let issues: [FeaturePackValidationIssue<Route>]

    public init(issues: [FeaturePackValidationIssue<Route>]) {
        self.issues = issues
    }

    public var isValid: Bool {
        issues.isEmpty
    }

    public var debugDescription: String {
        guard !issues.isEmpty else {
            return "FeaturePack is valid."
        }
        return (["FeaturePack validation failed:"] + issues.map { "- \($0.description)" }).joined(separator: "\n")
    }
}

public extension FeaturePack {
    func validate() -> FeaturePackValidationReport<Route> {
        var issues: [FeaturePackValidationIssue<Route>] = []

        for id in duplicateStrings(sidebar.map(\.id)) {
            issues.append(.duplicateSidebarID(id))
        }
        for id in duplicateStrings(routes.map(\.id)) {
            issues.append(.duplicateRouteID(id))
        }
        for id in duplicateStrings(commands.map(\.id)) {
            issues.append(.duplicateCommandID(id))
        }

        var contributionIDsByRoute: [Route: [String]] = [:]
        var routeOrder: [Route] = []

        for contribution in routes {
            if contributionIDsByRoute[contribution.route] == nil {
                routeOrder.append(contribution.route)
            }
            contributionIDsByRoute[contribution.route, default: []].append(contribution.id)
        }

        for route in routeOrder {
            let contributionIDs = contributionIDsByRoute[route] ?? []
            if contributionIDs.count > 1 {
                issues.append(.routeClaimedMultipleTimes(route: route, contributionIDs: contributionIDs))
            }
        }

        let declaredRoutes = Set(routes.map(\.route))

        for contribution in sidebar where !declaredRoutes.contains(contribution.route) {
            issues.append(.sidebarRouteNotDeclared(sidebarID: contribution.id, route: contribution.route))
        }

        for contribution in commands {
            guard let route = contribution.route else { continue }
            guard !declaredRoutes.contains(route) else { continue }
            issues.append(.commandRouteNotDeclared(commandID: contribution.id, route: route))
        }

        return FeaturePackValidationReport(issues: issues)
    }
}

private func duplicateStrings(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    var emitted: Set<String> = []
    var duplicates: [String] = []

    for value in values {
        if seen.insert(value).inserted {
            continue
        }
        if emitted.insert(value).inserted {
            duplicates.append(value)
        }
    }
    return duplicates
}
