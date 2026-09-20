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
            stripScrollers(from: view)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            stripScrollers(from: nsView)
        }
    }

    private func stripScrollers(from view: NSView?) {
        guard let view, let scrollView = view.enclosingScrollView else { return }
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScroller = nil
        scrollView.verticalScroller = nil
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
    }
}
#endif

public extension View {

    @ViewBuilder
    func hideScrollIndicatorsCompletely() -> some View {
        #if os(macOS)
        self
            .scrollIndicators(.hidden)
            .background(MacScrollIndicatorRemover())
        #else
        self
            .scrollIndicators(.hidden)
        #endif
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
