//
//  MacToolbarAdapter.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - macOS Semantic Toolbar Adapter

/// Renders a `ResolvedToolbarPresentation` using native AppKit.
///
/// This is deliberately a platform adapter:
///
/// semantic toolbar
///     ↓
/// ResolvedToolbarPresentation
///     ↓
/// MacToolbarAdapter
///     ↓
/// NSToolbar / NSSearchToolbarItem
///
/// It contains no route, scene, feature, or product knowledge.
@MainActor
public final class MacToolbarAdapter:
    NSObject,
    NSToolbarDelegate,
    NSToolbarItemValidation {

    public typealias PresentationProvider =
        @MainActor () -> ResolvedToolbarPresentation


    private let toolbar:
        NSToolbar

    private let presentation:
        PresentationProvider


    private let semanticPrefix =
        "AppFoundation.SemanticToolbar."


    public init(
        identifier:
            NSToolbar.Identifier,
        presentation:
            @escaping PresentationProvider
    ) {

        self.toolbar =
            NSToolbar(
                identifier:
                    identifier
            )

        self.presentation =
            presentation


        super.init()


        toolbar.delegate =
            self

        toolbar.displayMode =
            .iconOnly

        toolbar.allowsUserCustomization =
            false

        toolbar.autosavesConfiguration =
            false
    }


    // MARK: - Installation

    public func install(
        on window:
            NSWindow
    ) {

        window.toolbar =
            toolbar

        toolbar.isVisible =
            true
    }


    // MARK: - Reload

    public func reload() {
        let resolved = presentation()
        let targetIdentifiers = orderedIdentifiers(for: resolved)
        let currentIdentifiers = toolbar.items.map(\.itemIdentifier)

        if currentIdentifiers == targetIdentifiers {
            for item in resolved.items {
                let itemID = identifier(for: item.id)
                if let native = toolbar.items.first(where: { $0.itemIdentifier == itemID }) {
                    update(native, with: item)
                }
            }
        } else {
            for index in toolbar.items.indices.reversed() {
                toolbar.removeItem(at: index)
            }
            for itemID in targetIdentifiers {
                toolbar.insertItem(withItemIdentifier: itemID, at: toolbar.items.count)
            }
            for item in resolved.items {
                let itemID = identifier(for: item.id)
                if let native = toolbar.items.first(where: { $0.itemIdentifier == itemID }) {
                    update(native, with: item)
                }
            }
        }
    }

    private func orderedIdentifiers(for resolved: ResolvedToolbarPresentation) -> [NSToolbarItem.Identifier] {
        var result: [NSToolbarItem.Identifier] = [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace
        ]
        let searches = resolved.items.compactMap { item -> NSToolbarItem.Identifier? in
            guard case .search = item else { return nil }
            return identifier(for: item.id)
        }
        let actions = resolved.items.compactMap { item -> NSToolbarItem.Identifier? in
            guard case .action = item else { return nil }
            return identifier(for: item.id)
        }
        if !searches.isEmpty {
            result.append(contentsOf: searches)
            result.append(.flexibleSpace)
        }
        result.append(contentsOf: actions)
        return result
    }

    private func update(_ item: NSToolbarItem, with semantic: ResolvedToolbarItem) {
        item.autovalidates = false
        switch semantic {
        case .action(let action):
            item.label = action.title
            item.paletteLabel = action.title
            item.toolTip = action.title
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            item.image = NSImage(systemSymbolName: action.systemImage, accessibilityDescription: action.title)?
                .withSymbolConfiguration(symbolConfig)
            item.isEnabled = action.isEnabled
        case .search(let search):
            guard let searchItem = item as? NSSearchToolbarItem else { return }
            searchItem.isEnabled = search.isEnabled
            searchItem.searchField.isEnabled = search.isEnabled
            searchItem.searchField.placeholderString = search.prompt
            if searchItem.searchField.stringValue != search.text {
                searchItem.searchField.stringValue = search.text
            }
        }
    }


    // MARK: - Identifier Mapping

    private func identifier(
        for id:
            String
    ) -> NSToolbarItem.Identifier {

        NSToolbarItem.Identifier(
            semanticPrefix
            +
            id
        )
    }


    private func semanticID(
        from identifier:
            NSToolbarItem.Identifier
    ) -> String? {

        let rawValue =
            identifier
                .rawValue


        guard
            rawValue
                .hasPrefix(
                    semanticPrefix
                )
        else {

            return
                nil
        }


        return
            String(
                rawValue
                    .dropFirst(
                        semanticPrefix
                            .count
                    )
            )
    }


    // MARK: - Native Item Construction

    private func makeActionItem(
        identifier:
            NSToolbarItem.Identifier,
        action:
            ResolvedToolbarAction
    ) -> NSToolbarItem {

        let item =
            NSToolbarItem(
                itemIdentifier:
                    identifier
            )


        item.label =
            action.title

        item.paletteLabel =
            action.title

        item.toolTip =
            action.title

        let symbolConfig =
            NSImage.SymbolConfiguration(
                pointSize: 12,
                weight: .regular
            )

        item.image =
            NSImage(
                systemSymbolName:
                    action.systemImage,
                accessibilityDescription:
                    action.title
            )?.withSymbolConfiguration(
                symbolConfig
            )

        item.target =
            self

        item.action =
            #selector(
                performAction(
                    _:
                )
            )

        item.autovalidates = false
        item.isEnabled =
            action.isEnabled


        return
            item
    }


    private func makeSearchItem(
        identifier:
            NSToolbarItem.Identifier,
        search:
            ResolvedToolbarSearch
    ) -> NSToolbarItem {

        let item =
            NSSearchToolbarItem(
                itemIdentifier:
                    identifier
            )


        item.label =
            "Search"

        item.paletteLabel =
            "Search"

        item.autovalidates = false
        item.isEnabled =
            search.isEnabled
        item.searchField.isEnabled = search.isEnabled


        let field =
            item.searchField


        field.identifier =
            NSUserInterfaceItemIdentifier(
                identifier
                    .rawValue
            )

        field.placeholderString =
            search.prompt

        field.stringValue =
            search.text

        field.sendsSearchStringImmediately =
            true

        field.target =
            self

        field.action =
            #selector(
                searchChanged(
                    _:
                )
            )


        return
            item
    }


    // MARK: - Actions

    @objc
    private func performAction(
        _ sender:
            NSToolbarItem
    ) {

        guard
            let id =
                semanticID(
                    from:
                        sender
                            .itemIdentifier
                ),
            let item =
                presentation()
                    .item(
                        id:
                            id
                    ),
            case .action(
                let action
            ) =
                item
        else {

            return
        }


        guard action.isEnabled else { return }
        action.perform()


        toolbar
            .validateVisibleItems()
    }


    @objc
    private func searchChanged(
        _ sender:
            NSSearchField
    ) {

        guard
            let rawIdentifier =
                sender
                    .identifier?
                    .rawValue
        else {

            return
        }


        let identifier =
            NSToolbarItem.Identifier(
                rawIdentifier
            )


        guard
            let id =
                semanticID(
                    from:
                        identifier
                ),
            let item =
                presentation()
                    .item(
                        id:
                            id
                    ),
            case .search(
                let search
            ) =
                item
        else {

            return
        }


        guard search.isEnabled else { return }
        search.update(
            sender
                .stringValue
        )
    }


    public func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let id = semanticID(from: item.itemIdentifier),
              let semantic = presentation().item(id: id) else { return false }
        switch semantic {
        case .action(let action): return action.isEnabled
        case .search(let search): return search.isEnabled
        }
    }

    // MARK: - NSToolbarDelegate

    public func toolbarDefaultItemIdentifiers(
        _ toolbar:
            NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {
        orderedIdentifiers(for: presentation())
    }


    public func toolbarAllowedItemIdentifiers(
        _ toolbar:
            NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace
        ]
        +
        presentation()
            .items
            .map {
                identifier(
                    for:
                        $0.id
                )
            }
    }


    public func toolbar(
        _ toolbar:
            NSToolbar,
        itemForItemIdentifier itemIdentifier:
            NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag:
            Bool
    ) -> NSToolbarItem? {

        if itemIdentifier == .toggleSidebar {
            let item =
                NSToolbarItem(
                    itemIdentifier:
                        .toggleSidebar
                )
            item.label = "Sidebar"
            item.paletteLabel = "Sidebar"
            item.toolTip = "Toggle Sidebar"
            let symbolConfig =
                NSImage.SymbolConfiguration(
                    pointSize: 12,
                    weight: .regular
                )
            item.image =
                NSImage(
                    systemSymbolName:
                        "sidebar.left",
                    accessibilityDescription:
                        "Toggle Sidebar"
                )?.withSymbolConfiguration(
                    symbolConfig
                )
            item.target = nil
            item.action =
                #selector(
                    NSSplitViewController.toggleSidebar(_:)
                )
            return item
        }

        if itemIdentifier == .flexibleSpace {
            return NSToolbarItem(itemIdentifier: .flexibleSpace)
        }

        if itemIdentifier == .sidebarTrackingSeparator {
            return NSToolbarItem(itemIdentifier: .sidebarTrackingSeparator)
        }

        guard
            let id =
                semanticID(
                    from:
                        itemIdentifier
                ),
            let item =
                presentation()
                    .item(
                        id:
                            id
                    )
        else {

            return
                nil
        }


        switch item {

        case .action(
            let action
        ):

            return
                makeActionItem(
                    identifier:
                        itemIdentifier,
                    action:
                        action
                )


        case .search(
            let search
        ):

            return
                makeSearchItem(
                    identifier:
                        itemIdentifier,
                    search:
                        search
                )
        }
    }
}

#endif
