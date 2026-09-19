//
//  ApplicationDefinition+Workspace.swift
//  AppFoundationUI
//

// MARK: - Workspace Resolution

@MainActor
public extension ApplicationDefinition {

    func workspace(
        for route:
            Route,
        context:
            Context
    ) -> WorkspacePresentation<Context>? {

        routeDestinations
            .first {
                $0.matches(
                    route
                )
            }?
            .workspace(
                for:
                    route,
                context:
                    context
            )
    }
}
