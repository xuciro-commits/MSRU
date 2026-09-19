//
//  ToolbarItemPresentation.swift
//  AppFoundationUI
//

// MARK: - Toolbar Item Presentation

@MainActor
public enum ToolbarItemPresentation<Context> {

    case action(
        ToolbarActionPresentation<Context>
    )

    case search(
        ToolbarSearchPresentation<Context>
    )


    public var id:
        String {

        switch self {

        case .action(
            let action
        ):

            action.id


        case .search(
            let search
        ):

            search.id
        }
    }


    func resolve(
        for context:
            Context
    ) -> ResolvedToolbarItem {

        switch self {

        case .action(
            let action
        ):

            .action(
                action.resolve(
                    for:
                        context
                )
            )


        case .search(
            let search
        ):

            .search(
                search.resolve(
                    for:
                        context
                )
            )
        }
    }
}
