//
//  MacScrollViewModifiers.swift
//  AppFoundationUI
//

import SwiftUI

#if os(macOS)
import AppKit

@MainActor
public enum MacScrollIndicatorSuppressor {

    public static func suppressScrollIndicators(in root: NSView) {
        if let scrollView = root as? NSScrollView {
            suppress(scrollView: scrollView)
        }
        for subview in root.subviews {
            suppressScrollIndicators(in: subview)
        }
    }

    public static func suppress(scrollView: NSScrollView) {
        var didChange = false
        if scrollView.scrollerStyle != .overlay {
            scrollView.scrollerStyle = .overlay
            didChange = true
        }
        if scrollView.hasVerticalScroller {
            scrollView.hasVerticalScroller = false
            didChange = true
        }
        if scrollView.hasHorizontalScroller {
            scrollView.hasHorizontalScroller = false
            didChange = true
        }
        if let v = scrollView.verticalScroller, (!v.isHidden || v.alphaValue > 0) {
            v.alphaValue = 0
            v.isHidden = true
            didChange = true
        }
        if let h = scrollView.horizontalScroller, (!h.isHidden || h.alphaValue > 0) {
            h.alphaValue = 0
            h.isHidden = true
            didChange = true
        }
        if didChange {
            scrollView.tile()
        }
    }
}

public final class MacScrollIndicatorSuppressorView: NSView {

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            suppressNow()
        }
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview != nil {
            suppressNow()
        }
    }

    public func suppressNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let sv = self.enclosingScrollView {
                MacScrollIndicatorSuppressor.suppress(scrollView: sv)
            }
            var parent: NSView? = self.superview
            while let p = parent {
                if let sv = p as? NSScrollView {
                    MacScrollIndicatorSuppressor.suppress(scrollView: sv)
                }
                MacScrollIndicatorSuppressor.suppressScrollIndicators(in: p)
                if p is NSWindow || p.superview == nil { break }
                parent = p.superview
            }
        }
    }
}

public struct MacScrollIndicatorRemover: NSViewRepresentable {

    public init() {}

    public func makeNSView(context: Context) -> NSView {
        MacScrollIndicatorSuppressorView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // Once applied, the scroll indicator suppression is persistent on the enclosing NSScrollView.
        // No-op here prevents repeated hierarchy traversals on every SwiftUI state render pass.
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
