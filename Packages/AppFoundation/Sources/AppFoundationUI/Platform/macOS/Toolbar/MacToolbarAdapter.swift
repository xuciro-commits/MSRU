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
            guard let searchItem = item as? NSSearchToolbarItem else { return }
            searchItem.isEnabled = search.isEnabled
            searchItem.searchField.isEnabled = search.isEnabled
            searchItem.searchField.placeholderString = search.prompt
            if searchItem.searchField.stringValue != search.text {
                searchItem.searchField.stringValue = search.text
            }
            applyGlassStyle(to: searchItem.searchField)
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
        item.preferredWidthForSearchField = 350


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

        applyGlassStyle(to: field)

        return
            item
    }


    private func applyGlassStyle(to field: NSSearchField) {
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13, weight: .regular)
        field.drawsBackground = false
        field.isBezeled = false
        field.wantsLayer = true

        let effectID = NSUserInterfaceItemIdentifier("AppFoundation.Search.GlassBackground")
        if field.subviews.first(where: { $0.identifier == effectID }) == nil {
            let effectView = NSVisualEffectView(frame: field.bounds)
            effectView.identifier = effectID
            effectView.autoresizingMask = [.width, .height]
            effectView.material = .headerView
            effectView.blendingMode = .withinWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = 9
            effectView.layer?.masksToBounds = true
            effectView.layer?.borderWidth = 0.5
            effectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
            effectView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.04).cgColor
            effectView.layer?.shadowRadius = 4
            effectView.layer?.shadowOpacity = 1
            effectView.layer?.shadowOffset = CGSize(width: 0, height: -1)
            field.addSubview(effectView, positioned: .below, relativeTo: nil)
        }
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
