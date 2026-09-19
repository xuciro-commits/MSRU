//
//  ApplicationDefinitionValidation.swift
//  AppFoundationUI
//

import AppFoundation


// MARK: - Validation Issue

public enum ApplicationDefinitionValidationIssue<Route>:
    Equatable,
    Sendable,
    CustomStringConvertible
where
    Route:
        Hashable & Sendable {

    case composition(
        FeaturePackValidationIssue<Route>
    )

    case duplicateDestinationID(
        String
    )

    case routeWithoutDestination(
        routeID: String,
        route: Route
    )

    case destinationWithoutDeclaredRoute(
        destinationID: String
    )

    case routeMatchedByMultipleDestinations(
        routeID: String,
        route: Route,
        destinationIDs: [String]
    )


    // MARK: - Description

    public var description:
        String {

        switch self {

        case .composition(
            let issue
        ):

            return
                issue.description


        case .duplicateDestinationID(
            let id
        ):

            return
                "Duplicate route destination ID: \(id)"


        case .routeWithoutDestination(
            let routeID,
            let route
        ):

            return
                """
                Route contribution '\(routeID)' has no destination: \
                \(String(describing: route))
                """


        case .destinationWithoutDeclaredRoute(
            let destinationID
        ):

            return
                """
                Route destination '\(destinationID)' \
                does not match any declared route.
                """


        case .routeMatchedByMultipleDestinations(
            let routeID,
            let route,
            let destinationIDs
        ):

            return
                """
                Route contribution '\(routeID)' \
                \(String(describing: route)) is matched by multiple destinations: \
                \(destinationIDs.joined(separator: ", "))
                """
        }
    }
}


// MARK: - Validation Report

public struct ApplicationDefinitionValidationReport<Route>:
    Sendable
where
    Route:
        Hashable & Sendable {

    public let issues:
        [
            ApplicationDefinitionValidationIssue<Route>
        ]


    public init(
        issues:
            [
                ApplicationDefinitionValidationIssue<Route>
            ]
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
                "ApplicationDefinition is valid."
        }


        return
            (
                [
                    "ApplicationDefinition validation failed:"
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


// MARK: - ApplicationDefinition Validation

public extension ApplicationDefinition {

    func validate()
        -> ApplicationDefinitionValidationReport<Route> {

        var issues:
            [
                ApplicationDefinitionValidationIssue<Route>
            ] = []


        // MARK: Core Composition

        let compositionReport =
            featurePack
                .validate()


        issues.append(
            contentsOf:
                compositionReport
                    .issues
                    .map {
                        .composition(
                            $0
                        )
                    }
        )


        // MARK: Destination IDs

        for id in
            duplicateDestinationIDs(
                routeDestinations
                    .map(\.id)
            ) {

            issues.append(
                .duplicateDestinationID(
                    id
                )
            )
        }


        // MARK: Route -> Destination

        for contribution in
            routes {

            let matchingDestinations =
                routeDestinations
                    .filter {
                        $0.matches(
                            contribution.route
                        )
                    }


            if matchingDestinations.isEmpty {

                issues.append(
                    .routeWithoutDestination(
                        routeID:
                            contribution.id,
                        route:
                            contribution.route
                    )
                )

                continue
            }


            if matchingDestinations.count > 1 {

                issues.append(
                    .routeMatchedByMultipleDestinations(
                        routeID:
                            contribution.id,
                        route:
                            contribution.route,
                        destinationIDs:
                            matchingDestinations
                                .map(\.id)
                    )
                )
            }
        }


        // MARK: Destination -> Route

        for destination in
            routeDestinations {

            let matchesDeclaredRoute =
                routes
                    .contains {
                        destination
                            .matches(
                                $0.route
                            )
                    }


            if !matchesDeclaredRoute {

                issues.append(
                    .destinationWithoutDeclaredRoute(
                        destinationID:
                            destination.id
                    )
                )
            }
        }


        return
            ApplicationDefinitionValidationReport(
                issues:
                    issues
            )
    }
}


// MARK: - Helpers

private func duplicateDestinationIDs(
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
