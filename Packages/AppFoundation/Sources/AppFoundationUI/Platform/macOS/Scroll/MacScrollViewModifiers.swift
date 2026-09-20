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
        stripScrollers(from: nsView)
    }

    private func stripScrollers(from view: NSView?) {
        guard let view, let scrollView = view.enclosingScrollView else { return }
        if scrollView.scrollerStyle != .overlay {
            scrollView.scrollerStyle = .overlay
        }
        if !scrollView.autohidesScrollers {
            scrollView.autohidesScrollers = true
        }
        if let h = scrollView.horizontalScroller, h.alphaValue != 0 {
            h.alphaValue = 0
        }
        if let v = scrollView.verticalScroller, v.alphaValue != 0 {
            v.alphaValue = 0
        }
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
