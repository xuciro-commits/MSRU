//
//  MacApplicationWindowFactory.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - macOS Application Window Factory

@MainActor
public enum MacApplicationWindowFactory {

    public static func makeWindow(
        contentViewController:
            NSViewController,
        configuration:
            MacWindowConfiguration
    ) -> NSWindow {

        let window =
            NSWindow(
                contentRect:
                    NSRect(
                        origin:
                            .zero,
                        size:
                            configuration
                                .initialSize
                    ),
                styleMask:
                    [
                        .titled,
                        .closable,
                        .miniaturizable,
                        .resizable,
                        .fullSizeContentView
                    ],
                backing:
                    .buffered,
                defer:
                    false
            )


        /*
         Install the content controller before toolbar creation.

         Native tracking separators require the tracked split view
         to already belong to the same window.
         */

        window.contentViewController =
            contentViewController


        window.title =
            configuration
                .title

        window.titleVisibility =
            configuration
                .titleVisibility

        window.titlebarAppearsTransparent =
            configuration
                .titlebarAppearsTransparent

        window.titlebarSeparatorStyle =
            configuration
                .titlebarSeparatorStyle

        window.toolbarStyle =
            configuration
                .toolbarStyle

        window.minSize =
            configuration
                .minimumSize

        window.contentMinSize =
            configuration
                .minimumSize

        window.isReleasedWhenClosed =
            configuration
                .isReleasedWhenClosed

        window.collectionBehavior
            .insert(
                .fullScreenPrimary
            )


        if configuration
            .centerOnCreation {

            window.center()
        }


        return
            window
    }
}

#endif
