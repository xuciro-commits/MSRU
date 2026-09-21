//
//  MacHostingControllerFactory.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI


@MainActor
public final class MacSplitHostingController<Content: View>: NSHostingController<Content> {

    public override func viewWillAppear() {
        super.viewWillAppear()
        MacScrollIndicatorSuppressor.suppressScrollIndicators(in: view)
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        MacScrollIndicatorSuppressor.suppressScrollIndicators(in: view)
    }
}

// MARK: - SwiftUI Hosting

/// Creates SwiftUI hosting controllers suitable for AppKit-managed
/// split-view geometry.
///
/// Intrinsic SwiftUI sizing is deliberately disabled so the native
/// split controller remains the geometry owner.
@MainActor
public enum MacHostingControllerFactory {

    public static func make<
        Content:
            View
    >(
        rootView:
            Content
    ) -> NSHostingController<Content> {

        let controller =
            MacSplitHostingController(
                rootView:
                    rootView
            )


        controller.sizingOptions =
            []


        return
            controller
    }
}

#endif
