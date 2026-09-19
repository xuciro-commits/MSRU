//
//  ToolbarSearchPresentation.swift
//  AppFoundationUI
//

// MARK: - Toolbar Search Presentation

/// Semantic search contribution for a toolbar.
///
/// The framework owns no search state.
/// State and actions remain in the feature or scene supplied as Context.
@MainActor
public struct ToolbarSearchPresentation<Context> {

    public let id:
        String

    public let prompt:
        String


    private let textValue:
        (Context) -> String

    private let isEnabledValue:
        (Context) -> Bool

    private let updateAction:
        (
            Context,
            String
        ) -> Void


    public init(
        id:
            String,
        prompt:
            String,
        text:
            @escaping (Context) -> String,
        isEnabled:
            @escaping (Context) -> Bool = {
                _ in

                true
            },
        update:
            @escaping (
                Context,
                String
            ) -> Void
    ) {

        self.id =
            id

        self.prompt =
            prompt

        self.textValue =
            text

        self.isEnabledValue =
            isEnabled

        self.updateAction =
            update
    }


    func resolve(
        for context:
            Context
    ) -> ResolvedToolbarSearch {

        ResolvedToolbarSearch(
            id:
                id,
            prompt:
                prompt,
            text:
                textValue(
                    context
                ),
            isEnabled:
                isEnabledValue(
                    context
                ),
            update: {
                value in

                updateAction(
                    context,
                    value
                )
            }
        )
    }
}
