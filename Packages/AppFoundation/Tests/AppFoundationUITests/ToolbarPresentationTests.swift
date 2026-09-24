//
//  ToolbarPresentationTests.swift
//  AppFoundationUITests
//

import Testing
import SwiftUI
@testable import AppFoundationUI
#if os(macOS)
import AppKit
#endif

@MainActor
private final class ToolbarTestModel {
    var query: String
    var actionCount = 0

    init(query: String = "") {
        self.query = query
    }
}

struct ToolbarPresentationTests {

    @Test
    @MainActor
    func actionResolvesAgainstContext() {
        let model = ToolbarTestModel()
        let toolbar = ToolbarPresentation<ToolbarTestModel>(
            items: [
                .action(
                    ToolbarActionPresentation(
                        id: "run",
                        title: "Run",
                        systemImage: "play.fill",
                        perform: { model in
                            model.actionCount += 1
                        }
                    )
                )
            ]
        )

        let resolved = toolbar.resolved(for: model)

        guard case .action(let action) = resolved.items.first else {
            Issue.record("Expected resolved toolbar action.")
            return
        }

        action.perform()
        #expect(model.actionCount == 1)
    }

    @Test
    @MainActor
    func searchResolvesStateAndAction() {
        let model = ToolbarTestModel(query: "initial")
        let toolbar = ToolbarPresentation<ToolbarTestModel>(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "search",
                        prompt: "Search",
                        text: { model in model.query },
                        update: { model, value in model.query = value }
                    )
                )
            ]
        )

        let resolved = toolbar.resolved(for: model)

        guard case .search(let search) = resolved.items.first else {
            Issue.record("Expected resolved toolbar search.")
            return
        }

        #expect(search.text == "initial")
        search.update("updated")
        #expect(model.query == "updated")
    }

    @Test
    @MainActor
    func resolvedPresentationsMergeAcrossDifferentContexts() {
        let first = ResolvedToolbarPresentation(items: [])
        let second = ResolvedToolbarPresentation(items: [])
        let merged = first.merging(second)
        #expect(merged.items.isEmpty)
    }

    #if os(macOS)
    @Test
    @MainActor
    func macToolbarAdapterReloadUpdatesValuesWithoutReplacingSearchField() throws {
        var text = "first"
        var enabled = true
        let adapter = MacToolbarAdapter(identifier: "Fixture.Toolbar") {
            ResolvedToolbarPresentation(items: [
                .search(ResolvedToolbarSearch(id: "query", prompt: "Find", text: text,
                    isEnabled: enabled, update: { text = $0 })),
                .action(ResolvedToolbarAction(id: "save", title: "Save", systemImage: "square.and.arrow.down",
                    isEnabled: enabled, perform: {}))
            ])
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        adapter.install(on: window)
        adapter.reload()
        let toolbar = try #require(window.toolbar)
        let search = try #require(toolbar.items.compactMap { $0 as? NSSearchToolbarItem }.first)
        let action = try #require(toolbar.items.first { $0.itemIdentifier.rawValue.hasSuffix(".save") })
        #expect(search.searchField.stringValue == "first")
        let originalField = search.searchField
        text = "updated externally"
        enabled = false
        adapter.reload()
        let updatedSearch = try #require(toolbar.items.compactMap { $0 as? NSSearchToolbarItem }.first)
        #expect(updatedSearch === search)
        #expect(updatedSearch.searchField === originalField)
        #expect(updatedSearch.searchField.stringValue == text)
        #expect(!updatedSearch.searchField.isEnabled)
        #expect(!action.isEnabled)
        toolbar.validateVisibleItems()
        #expect(!action.isEnabled)
    }

    @Test
    @MainActor
    func macToolbarLayoutCentersSearchAndPlacesActionAtTrailingEdge() throws {
        let adapter = MacToolbarAdapter(identifier: "Fixture.LayoutToolbar") {
            ResolvedToolbarPresentation(items: [
                .search(ResolvedToolbarSearch(id: "browse.search", prompt: "Search", text: "query", isEnabled: true, update: { _ in })),
                .action(ResolvedToolbarAction(id: "toggleQueue", title: "Inspector", systemImage: "sidebar.right", isEnabled: true, perform: {}))
            ])
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        adapter.install(on: window)
        adapter.reload()
        let toolbar = try #require(window.toolbar)
        let ids = toolbar.items.map(\.itemIdentifier)

        #expect(ids == [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            NSToolbarItem.Identifier("AppFoundation.SemanticToolbar.browse.search"),
            .flexibleSpace,
            NSToolbarItem.Identifier("AppFoundation.SemanticToolbar.toggleQueue")
        ])
    }

    @Test
    @MainActor
    func macToolbarLayoutTracksContextDividerWhenSplitViewHasContext() throws {
        let splitView = NSSplitView()
        splitView.addArrangedSubview(NSView())
        splitView.addArrangedSubview(NSView())
        splitView.addArrangedSubview(NSView())

        let adapter = MacToolbarAdapter(identifier: "Fixture.SplitLayoutToolbar") {
            ResolvedToolbarPresentation(items: [
                .search(ResolvedToolbarSearch(id: "radio.search", prompt: "Search", text: "query", isEnabled: true, update: { _ in })),
                .action(ResolvedToolbarAction(id: "toggleQueue", title: "Inspector", systemImage: "sidebar.right", isEnabled: true, perform: {}))
            ])
        }
        adapter.trackingSplitView = splitView
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        adapter.install(on: window)
        adapter.reload()
        let toolbar = try #require(window.toolbar)
        let ids = toolbar.items.map(\.itemIdentifier)

        #expect(ids == [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            NSToolbarItem.Identifier("AppFoundation.SemanticToolbar.radio.search"),
            .flexibleSpace,
            MacToolbarAdapter.contextTrackingSeparator,
            NSToolbarItem.Identifier("AppFoundation.SemanticToolbar.toggleQueue")
        ])
    }
    #endif
}
