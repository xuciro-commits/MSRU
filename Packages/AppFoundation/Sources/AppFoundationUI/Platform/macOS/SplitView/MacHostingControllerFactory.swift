//
//  MacHostingControllerFactory.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI


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
            NSHostingController(
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
