//
//  ToolbarPresentation.swift
//  AppFoundationUI
//

// MARK: - Toolbar Presentation

/// Semantic toolbar contribution surface.
///
/// The generic Context is intentionally erased by `resolved(for:)`.
///
/// This allows application, workspace, and selection contributions
/// to use different context types before being merged by a platform shell.
@MainActor
public struct ToolbarPresentation<Context> {

    public let items:
        [ToolbarItemPresentation<Context>]


    public init(
        items:
            [ToolbarItemPresentation<Context>] = []
    ) {

        let identifiers =
            items.map(
                \.id
            )


        precondition(
            Set(
                identifiers
            ).count
            ==
            identifiers.count,
            "Toolbar item identifiers must be unique."
        )


        self.items =
            items
    }


    public var isEmpty:
        Bool {

        items.isEmpty
    }


    public func resolved(
        for context:
            Context
    ) -> ResolvedToolbarPresentation {

        ResolvedToolbarPresentation(
            items:
                items.map {
                    $0.resolve(
                        for:
                            context
                    )
                }
        )
    }
}
