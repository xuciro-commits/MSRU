//
//  ToolbarActionPresentation.swift
//  AppFoundationUI
//

// MARK: - Toolbar Action Presentation

/// Semantic description of an actionable toolbar contribution.
///
/// It describes intent and presentation metadata only.
/// Platform renderers decide whether this becomes an NSToolbarItem,
/// SwiftUI ToolbarItem, menu command, or another native control.
@MainActor
public struct ToolbarActionPresentation<Context> {

    public let id:
        String

    public let title:
        String

    public let systemImage:
        String


    private let isEnabledValue:
        (Context) -> Bool

    private let performAction:
        (Context) -> Void


    public init(
        id:
            String,
        title:
            String,
        systemImage:
            String,
        isEnabled:
            @escaping (Context) -> Bool = {
                _ in

                true
            },
        perform:
            @escaping (Context) -> Void
    ) {

        self.id =
            id

        self.title =
            title

        self.systemImage =
            systemImage

        self.isEnabledValue =
            isEnabled

        self.performAction =
            perform
    }


    func resolve(
        for context:
            Context
    ) -> ResolvedToolbarAction {

        ResolvedToolbarAction(
            id:
                id,
            title:
                title,
            systemImage:
                systemImage,
            isEnabled:
                isEnabledValue(
                    context
                ),
            perform: {
                performAction(
                    context
                )
            }
        )
    }
}
