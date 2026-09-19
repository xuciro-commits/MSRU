//
//  ResolvedToolbarPresentation.swift
//  AppFoundationUI
//

// MARK: - Resolved Toolbar Action

@MainActor
public struct ResolvedToolbarAction {

    public let id:
        String

    public let title:
        String

    public let systemImage:
        String

    public let isEnabled:
        Bool


    private let performAction:
        () -> Void


    init(
        id:
            String,
        title:
            String,
        systemImage:
            String,
        isEnabled:
            Bool,
        perform:
            @escaping () -> Void
    ) {

        self.id =
            id

        self.title =
            title

        self.systemImage =
            systemImage

        self.isEnabled =
            isEnabled

        self.performAction =
            perform
    }


    public func perform() {

        performAction()
    }
}


// MARK: - Resolved Toolbar Search

@MainActor
public struct ResolvedToolbarSearch {

    public let id:
        String

    public let prompt:
        String

    public let text:
        String

    public let isEnabled:
        Bool


    private let updateAction:
        (String) -> Void


    init(
        id:
            String,
        prompt:
            String,
        text:
            String,
        isEnabled:
            Bool,
        update:
            @escaping (String) -> Void
    ) {

        self.id =
            id

        self.prompt =
            prompt

        self.text =
            text

        self.isEnabled =
            isEnabled

        self.updateAction =
            update
    }


    public func update(
        _ value:
            String
    ) {

        updateAction(
            value
        )
    }
}


// MARK: - Resolved Toolbar Item

@MainActor
public enum ResolvedToolbarItem {

    case action(
        ResolvedToolbarAction
    )

    case search(
        ResolvedToolbarSearch
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
}


// MARK: - Resolved Toolbar Presentation

@MainActor
public struct ResolvedToolbarPresentation {

    public let items:
        [ResolvedToolbarItem]


    public init(
        items:
            [ResolvedToolbarItem] = []
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
            "Resolved toolbar item identifiers must be unique."
        )


        self.items =
            items
    }


    public func item(
        id:
            String
    ) -> ResolvedToolbarItem? {

        items
            .first {
                $0.id
                ==
                id
            }
    }


    public func merging(
        _ other:
            ResolvedToolbarPresentation
    ) -> ResolvedToolbarPresentation {

        ResolvedToolbarPresentation(
            items:
                items
                +
                other.items
        )
    }
}
