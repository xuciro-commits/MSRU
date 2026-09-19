//
//  FeaturePackValidation.swift
//  AppFoundation
//

import Foundation


// MARK: - Validation Issue

public enum FeaturePackValidationIssue<Route>:
    Equatable,
    Sendable,
    CustomStringConvertible
where
    Route:
        Hashable & Sendable {

    case duplicateSidebarID(
        String
    )

    case duplicateRouteID(
        String
    )

    case duplicateCommandID(
        String
    )

    case routeClaimedMultipleTimes(
        route: Route,
        contributionIDs: [String]
    )

    case sidebarRouteNotDeclared(
        sidebarID: String,
        route: Route
    )

    case commandRouteNotDeclared(
        commandID: String,
        route: Route
    )


    // MARK: - Description

    public var description:
        String {

        switch self {

        case .duplicateSidebarID(
            let id
        ):

            return
                "Duplicate sidebar contribution ID: \(id)"


        case .duplicateRouteID(
            let id
        ):

            return
                "Duplicate route contribution ID: \(id)"


        case .duplicateCommandID(
            let id
        ):

            return
                "Duplicate command contribution ID: \(id)"


        case .routeClaimedMultipleTimes(
            let route,
            let contributionIDs
        ):

            return
                """
                Route is claimed multiple times: \
                \(String(describing: route)) \
                by \(contributionIDs.joined(separator: ", "))
                """


        case .sidebarRouteNotDeclared(
            let sidebarID,
            let route
        ):

            return
                """
                Sidebar contribution '\(sidebarID)' points to \
                undeclared route: \(String(describing: route))
                """


        case .commandRouteNotDeclared(
            let commandID,
            let route
        ):

            return
                """
                Command contribution '\(commandID)' points to \
                undeclared route: \(String(describing: route))
                """
        }
    }
}


// MARK: - Validation Report

public struct FeaturePackValidationReport<Route>:
    Sendable
where
    Route:
        Hashable & Sendable {

    public let issues:
        [FeaturePackValidationIssue<Route>]


    public init(
        issues:
            [FeaturePackValidationIssue<Route>]
    ) {

        self.issues =
            issues
    }


    public var isValid:
        Bool {

        issues.isEmpty
    }


    public var debugDescription:
        String {

        guard
            !issues.isEmpty
        else {

            return
                "FeaturePack is valid."
        }


        return
            (
                [
                    "FeaturePack validation failed:"
                ]
                +
                issues
                    .map {
                        "- \($0.description)"
                    }
            )
            .joined(
                separator:
                    "\n"
            )
    }
}


// MARK: - FeaturePack Validation

public extension FeaturePack {

    func validate()
        -> FeaturePackValidationReport<Route> {

        var issues:
            [FeaturePackValidationIssue<Route>] = []


        // MARK: Duplicate IDs

        for id in
            duplicateStrings(
                sidebar.map(\.id)
            ) {

            issues.append(
                .duplicateSidebarID(
                    id
                )
            )
        }


        for id in
            duplicateStrings(
                routes.map(\.id)
            ) {

            issues.append(
                .duplicateRouteID(
                    id
                )
            )
        }


        for id in
            duplicateStrings(
                commands.map(\.id)
            ) {

            issues.append(
                .duplicateCommandID(
                    id
                )
            )
        }


        // MARK: Route Ownership

        var contributionIDsByRoute:
            [
                Route:
                    [String]
            ] = [:]

        var routeOrder:
            [Route] = []


        for contribution in
            routes {

            if contributionIDsByRoute[
                contribution.route
            ] == nil {

                routeOrder.append(
                    contribution.route
                )
            }


            contributionIDsByRoute[
                contribution.route,
                default:
                    []
            ]
            .append(
                contribution.id
            )
        }


        for route in
            routeOrder {

            let contributionIDs =
                contributionIDsByRoute[
                    route
                ]
                ??
                []


            if contributionIDs.count > 1 {

                issues.append(
                    .routeClaimedMultipleTimes(
                        route:
                            route,
                        contributionIDs:
                            contributionIDs
                    )
                )
            }
        }


        // MARK: Declared Routes

        let declaredRoutes =
            Set(
                routes
                    .map(\.route)
            )


        // MARK: Sidebar Integrity

        for contribution in
            sidebar
        where
            !declaredRoutes
                .contains(
                    contribution.route
                ) {

            issues.append(
                .sidebarRouteNotDeclared(
                    sidebarID:
                        contribution.id,
                    route:
                        contribution.route
                )
            )
        }


        // MARK: Command Integrity

        for contribution in
            commands {

            guard
                let route =
                    contribution.route
            else {

                continue
            }


            guard
                !declaredRoutes
                    .contains(
                        route
                    )
            else {

                continue
            }


            issues.append(
                .commandRouteNotDeclared(
                    commandID:
                        contribution.id,
                    route:
                        route
                )
            )
        }


        return
            FeaturePackValidationReport(
                issues:
                    issues
            )
    }
}


// MARK: - Helpers

private func duplicateStrings(
    _ values:
        [String]
) -> [String] {

    var seen:
        Set<String> = []

    var emitted:
        Set<String> = []

    var duplicates:
        [String] = []


    for value in
        values {

        if seen.insert(
            value
        )
        .inserted {

            continue
        }


        if emitted.insert(
            value
        )
        .inserted {

            duplicates.append(
                value
            )
        }
    }


    return
        duplicates
}
