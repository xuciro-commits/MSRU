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

    public static let contextTrackingSeparator =
        NSToolbarItem.Identifier("AppFoundation.Toolbar.contextTrackingSeparator")

    public weak var trackingSplitView: NSSplitView?

    private var hasContextDivider: Bool {
        guard let splitView = trackingSplitView else { return false }
        return splitView.arrangedSubviews.count > 2
    }


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
        if hasContextDivider {
            result.append(Self.contextTrackingSeparator)
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
            guard let searchItem = item as? MacSearchToolbarItem else { return }
            searchItem.isEnabled = search.isEnabled
            searchItem.state.update(from: search)
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
        MacSearchToolbarItem(
            identifier: identifier,
            search: search
        )
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
            Self.contextTrackingSeparator,
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
            if let splitView = trackingSplitView {
                return NSTrackingSeparatorToolbarItem(
                    identifier: .sidebarTrackingSeparator,
                    splitView: splitView,
                    dividerIndex: 0
                )
            }
            return NSToolbarItem(itemIdentifier: .sidebarTrackingSeparator)
        }

        if itemIdentifier == Self.contextTrackingSeparator {
            if let splitView = trackingSplitView, splitView.arrangedSubviews.count > 2 {
                return NSTrackingSeparatorToolbarItem(
                    identifier: Self.contextTrackingSeparator,
                    splitView: splitView,
                    dividerIndex: 1
                )
            }
            return NSToolbarItem(itemIdentifier: Self.contextTrackingSeparator)
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
