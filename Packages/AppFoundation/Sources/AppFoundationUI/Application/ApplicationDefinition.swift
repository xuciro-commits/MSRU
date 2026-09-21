//
//  ApplicationDefinition.swift
//  AppFoundationUI
//

import AppFoundation

// MARK: - Application Definition

@MainActor
public struct ApplicationDefinition<Route, Context> where Route: Hashable & Sendable {

    // MARK: - Structure
    public private(set) var featurePack: FeaturePack<Route>

    // MARK: - Presentation
    public private(set) var presentationPack: FeaturePresentationPack<Route, Context>

    // MARK: - Init
    public init() {
        self.featurePack = FeaturePack()
        self.presentationPack = FeaturePresentationPack()
    }

    // MARK: - Convenient Projections
    public var sidebar: [SidebarContribution<Route>] {
        featurePack.sidebar
    }

    public var routes: [RouteContribution<Route>] {
        featurePack.routes
    }

    public var commands: [CommandContribution<Route>] {
        featurePack.commands
    }

    public var routeDestinations: [RouteDestination<Route, Context>] {
        presentationPack.routeDestinations
    }

    // MARK: - Append
    public mutating func append(
        contribution: FeatureContribution<Route>,
        routeDestinations: [RouteDestination<Route, Context>]
    ) {
        featurePack.append(contribution)
        presentationPack.append(contentsOf: routeDestinations)
    }

    // MARK: - Normalize
    public mutating func normalize() {
        featurePack.normalize()
    }

    // MARK: - Workspace Resolution
    public func workspace(
        for route: Route,
        context: Context
    ) -> WorkspacePresentation<Context>? {
        routeDestinations
            .first { $0.matches(route) }?
            .workspace(for: route, context: context)
    }
}

// MARK: - Application Definition Builder

@MainActor
public struct ApplicationDefinitionBuilder<Route, Context> where Route: Hashable & Sendable {
    private var definition: ApplicationDefinition<Route, Context>

    public init() {
        self.definition = ApplicationDefinition()
    }

    @discardableResult
    public mutating func add<F>(_ feature: F.Type) -> Self
    where F: ApplicationFeaturePresentation, F.Route == Route, F.PresentationContext == Context {
        definition.append(
            contribution: F.contributions,
            routeDestinations: F.routeDestinations
        )
        return self
    }

    @discardableResult
    public mutating func addHost(
        contribution: FeatureContribution<Route>,
        routeDestinations: [RouteDestination<Route, Context>]
    ) -> Self {
        definition.append(
            contribution: contribution,
            routeDestinations: routeDestinations
        )
        return self
    }

    public func build() -> ApplicationDefinition<Route, Context> {
        var result = definition
        result.normalize()
        return result
    }
}

// MARK: - Validation Issue & Report

public enum ApplicationDefinitionValidationIssue<Route>: Equatable, Sendable, CustomStringConvertible where Route: Hashable & Sendable {
    case composition(FeaturePackValidationIssue<Route>)
    case duplicateDestinationID(String)
    case routeWithoutDestination(routeID: String, route: Route)
    case destinationWithoutDeclaredRoute(destinationID: String)
    case routeMatchedByMultipleDestinations(routeID: String, route: Route, destinationIDs: [String])

    public var description: String {
        switch self {
        case .composition(let issue):
            return issue.description
        case .duplicateDestinationID(let id):
            return "Duplicate route destination ID: \(id)"
        case .routeWithoutDestination(let routeID, let route):
            return "Route contribution '\(routeID)' has no destination: \(String(describing: route))"
        case .destinationWithoutDeclaredRoute(let destinationID):
            return "Route destination '\(destinationID)' does not match any declared route."
        case .routeMatchedByMultipleDestinations(let routeID, let route, let destinationIDs):
            return "Route contribution '\(routeID)' \(String(describing: route)) is matched by multiple destinations: \(destinationIDs.joined(separator: ", "))"
        }
    }
}

public struct ApplicationDefinitionValidationReport<Route>: Sendable where Route: Hashable & Sendable {
    public let issues: [ApplicationDefinitionValidationIssue<Route>]

    public init(issues: [ApplicationDefinitionValidationIssue<Route>]) {
        self.issues = issues
    }

    public var isValid: Bool {
        issues.isEmpty
    }

    public var debugDescription: String {
        guard !issues.isEmpty else {
            return "ApplicationDefinition is valid."
        }
        return (["ApplicationDefinition validation failed:"] + issues.map { "- \($0.description)" }).joined(separator: "\n")
    }
}

// MARK: - ApplicationDefinition Validation

public extension ApplicationDefinition {
    func validate() -> ApplicationDefinitionValidationReport<Route> {
        var issues: [ApplicationDefinitionValidationIssue<Route>] = []

        // Core Composition
        let compositionReport = featurePack.validate()
        issues.append(contentsOf: compositionReport.issues.map { .composition($0) })

        // Destination IDs
        for id in duplicateDestinationIDs(routeDestinations.map(\.id)) {
            issues.append(.duplicateDestinationID(id))
        }

        // Route -> Destination
        for contribution in routes {
            let matchingDestinations = routeDestinations.filter { $0.matches(contribution.route) }
            if matchingDestinations.isEmpty {
                issues.append(.routeWithoutDestination(routeID: contribution.id, route: contribution.route))
                continue
            }
            if matchingDestinations.count > 1 {
                issues.append(.routeMatchedByMultipleDestinations(routeID: contribution.id, route: contribution.route, destinationIDs: matchingDestinations.map(\.id)))
            }
        }

        // Destination -> Route
        for destination in routeDestinations {
            let matchesDeclaredRoute = routes.contains { destination.matches($0.route) }
            if !matchesDeclaredRoute {
                issues.append(.destinationWithoutDeclaredRoute(destinationID: destination.id))
            }
        }

        return ApplicationDefinitionValidationReport(issues: issues)
    }
}

private func duplicateDestinationIDs(_ values: [String]) -> [String] {
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
