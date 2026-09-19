#if os(macOS)
import AppKit
import Testing
@testable import AppFoundationUI

@MainActor
struct MacToolbarAdapterTests {
    @Test
    func reloadUpdatesValuesWithoutReplacingSearchField() throws {
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
}
#endif
