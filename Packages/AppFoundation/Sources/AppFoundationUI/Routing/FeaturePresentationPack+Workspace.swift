//
//  FeaturePresentationPack+Workspace.swift
//  AppFoundationUI
//

// MARK: - Workspace Resolution

@MainActor
public extension FeaturePresentationPack {

    /// Resolves the first destination matching `route` into its workspace.
    ///
    /// The presentation pack owns destination composition.
    /// The application shell therefore does not need to understand routing.
    func workspace(
        for route: Route,
        context: Context
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
