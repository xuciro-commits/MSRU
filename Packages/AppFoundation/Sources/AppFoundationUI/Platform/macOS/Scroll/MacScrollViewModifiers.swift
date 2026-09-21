//
//  MacScrollViewModifiers.swift
//  AppFoundationUI
//

import SwiftUI

#if os(macOS)
import AppKit

public struct MacScrollIndicatorRemover: NSViewRepresentable {

    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let view, let scrollView = view.enclosingScrollView else { return }
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // Intentionally empty: mutating enclosing NSScrollView properties during
        // SwiftUI layout passes triggers recursive layout feedback loops.
    }
}
#endif

public extension View {

    @ViewBuilder
    func hideScrollIndicatorsCompletely() -> some View {
        self
            .scrollIndicators(.hidden)
    }
}

#if os(macOS)
#Preview("Scroll Indicator Remover") {
    ScrollView {
        Text("Scroll Preview Content")
            .padding()
    }
    .background(MacScrollIndicatorRemover())
    .frame(width: 200, height: 200)
}
#endif
