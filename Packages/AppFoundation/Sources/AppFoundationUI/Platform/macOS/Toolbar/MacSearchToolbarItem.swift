//
//  MacSearchToolbarItem.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI


// MARK: - Mac Toolbar Search State

@MainActor
public final class MacToolbarSearchState: ObservableObject {

    @Published public var prompt: String
    @Published public var text: String
    @Published public var isEnabled: Bool

    var onUpdate: ((String) -> Void)?


    public init(
        prompt: String,
        text: String,
        isEnabled: Bool,
        onUpdate: ((String) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.text = text
        self.isEnabled = isEnabled
        self.onUpdate = onUpdate
    }


    public func update(from search: ResolvedToolbarSearch) {
        if prompt != search.prompt {
            prompt = search.prompt
        }
        if text != search.text {
            text = search.text
        }
        if isEnabled != search.isEnabled {
            isEnabled = search.isEnabled
        }
        onUpdate = { [search] value in
            search.update(value)
        }
    }
}


// MARK: - Mac Toolbar Search Field (SwiftUI)

@MainActor
public struct MacToolbarSearchField: View {

    @ObservedObject public var state: MacToolbarSearchState


    public init(state: MacToolbarSearchState) {
        self.state = state
    }


    public var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(state.prompt, text: Binding(
                get: { state.text },
                set: { newValue in
                    state.text = newValue
                    state.onUpdate?(newValue)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .regular))
            .disabled(!state.isEnabled)
            .onKeyPress(.escape) {
                if !state.text.isEmpty {
                    state.text = ""
                    state.onUpdate?("")
                    return .handled
                }
                return .ignored
            }

            if !state.text.isEmpty {
                Button {
                    state.text = ""
                    state.onUpdate?("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 350, height: 36)
    }
}


// MARK: - Mac Search Toolbar Item (Native NSToolbarItem)

@MainActor
public final class MacSearchToolbarItem: NSToolbarItem {

    public let state: MacToolbarSearchState
    public let hostingView: NSHostingView<MacToolbarSearchField>

    public var text: String { state.text }
    public var prompt: String { state.prompt }


    public init(
        identifier: NSToolbarItem.Identifier,
        search: ResolvedToolbarSearch
    ) {
        let state = MacToolbarSearchState(
            prompt: search.prompt,
            text: search.text,
            isEnabled: search.isEnabled,
            onUpdate: { value in
                search.update(value)
            }
        )
        self.state = state
        let hostingView = NSHostingView(rootView: MacToolbarSearchField(state: state))
        self.hostingView = hostingView

        super.init(itemIdentifier: identifier)

        self.label = "Search"
        self.paletteLabel = "Search"
        self.toolTip = "Search"
        self.autovalidates = false
        self.isEnabled = search.isEnabled

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.widthAnchor.constraint(equalToConstant: 350),
            hostingView.heightAnchor.constraint(equalToConstant: 36)
        ])
        self.view = hostingView
    }
}


// MARK: - Preview

#Preview("MacToolbarSearchField") {
    MacToolbarSearchField(
        state: MacToolbarSearchState(
            prompt: "Filter artists…",
            text: "Beatles",
            isEnabled: true
        )
    )
    .padding(20)
}

#endif
