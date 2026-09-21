//
//  ToolbarPresentation.swift
//  AppFoundationUI
//

import Foundation

// MARK: - Toolbar Action Presentation

/// Semantic description of an actionable toolbar contribution.
@MainActor
public struct ToolbarActionPresentation<Context> {
    public let id: String
    public let title: String
    public let systemImage: String

    private let isEnabledValue: (Context) -> Bool
    private let performAction: (Context) -> Void

    public init(
        id: String,
        title: String,
        systemImage: String,
        isEnabled: @escaping (Context) -> Bool = { _ in true },
        perform: @escaping (Context) -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isEnabledValue = isEnabled
        self.performAction = perform
    }

    func resolve(for context: Context) -> ResolvedToolbarAction {
        ResolvedToolbarAction(
            id: id,
            title: title,
            systemImage: systemImage,
            isEnabled: isEnabledValue(context),
            perform: { performAction(context) }
        )
    }
}

// MARK: - Toolbar Search Presentation

/// Semantic search contribution for a toolbar.
@MainActor
public struct ToolbarSearchPresentation<Context> {
    public let id: String
    public let prompt: String

    private let textValue: (Context) -> String
    private let isEnabledValue: (Context) -> Bool
    private let updateAction: (Context, String) -> Void

    public init(
        id: String,
        prompt: String,
        text: @escaping (Context) -> String,
        isEnabled: @escaping (Context) -> Bool = { _ in true },
        update: @escaping (Context, String) -> Void
    ) {
        self.id = id
        self.prompt = prompt
        self.textValue = text
        self.isEnabledValue = isEnabled
        self.updateAction = update
    }

    func resolve(for context: Context) -> ResolvedToolbarSearch {
        ResolvedToolbarSearch(
            id: id,
            prompt: prompt,
            text: textValue(context),
            isEnabled: isEnabledValue(context),
            update: { value in updateAction(context, value) }
        )
    }
}

// MARK: - Resolved Toolbar Action

@MainActor
public struct ResolvedToolbarAction {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isEnabled: Bool

    private let performAction: () -> Void

    init(
        id: String,
        title: String,
        systemImage: String,
        isEnabled: Bool,
        perform: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.performAction = perform
    }

    public func perform() {
        performAction()
    }
}

// MARK: - Resolved Toolbar Search

@MainActor
public struct ResolvedToolbarSearch {
    public let id: String
    public let prompt: String
    public let text: String
    public let isEnabled: Bool

    private let updateAction: (String) -> Void

    init(
        id: String,
        prompt: String,
        text: String,
        isEnabled: Bool,
        update: @escaping (String) -> Void
    ) {
        self.id = id
        self.prompt = prompt
        self.text = text
        self.isEnabled = isEnabled
        self.updateAction = update
    }

    public func update(_ value: String) {
        updateAction(value)
    }
}

// MARK: - Resolved Toolbar Item

@MainActor
public enum ResolvedToolbarItem {
    case action(ResolvedToolbarAction)
    case search(ResolvedToolbarSearch)

    public var id: String {
        switch self {
        case .action(let action):
            action.id
        case .search(let search):
            search.id
        }
    }
}

// MARK: - Resolved Toolbar Presentation

@MainActor
public struct ResolvedToolbarPresentation {
    public let items: [ResolvedToolbarItem]

    public init(items: [ResolvedToolbarItem] = []) {
        let identifiers = items.map(\.id)
        precondition(
            Set(identifiers).count == identifiers.count,
            "Resolved toolbar item identifiers must be unique."
        )
        self.items = items
    }

    public func item(id: String) -> ResolvedToolbarItem? {
        items.first { $0.id == id }
    }

    public func merging(_ other: ResolvedToolbarPresentation) -> ResolvedToolbarPresentation {
        ResolvedToolbarPresentation(items: items + other.items)
    }
}

// MARK: - Toolbar Item Presentation

@MainActor
public enum ToolbarItemPresentation<Context> {
    case action(ToolbarActionPresentation<Context>)
    case search(ToolbarSearchPresentation<Context>)

    public var id: String {
        switch self {
        case .action(let action):
            action.id
        case .search(let search):
            search.id
        }
    }

    func resolve(for context: Context) -> ResolvedToolbarItem {
        switch self {
        case .action(let action):
            .action(action.resolve(for: context))
        case .search(let search):
            .search(search.resolve(for: context))
        }
    }
}

// MARK: - Toolbar Presentation

@MainActor
public struct ToolbarPresentation<Context> {
    public let items: [ToolbarItemPresentation<Context>]

    public init(items: [ToolbarItemPresentation<Context>] = []) {
        let identifiers = items.map(\.id)
        precondition(
            Set(identifiers).count == identifiers.count,
            "Toolbar item identifiers must be unique."
        )
        self.items = items
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public func resolved(for context: Context) -> ResolvedToolbarPresentation {
        ResolvedToolbarPresentation(
            items: items.map { $0.resolve(for: context) }
        )
    }
}
