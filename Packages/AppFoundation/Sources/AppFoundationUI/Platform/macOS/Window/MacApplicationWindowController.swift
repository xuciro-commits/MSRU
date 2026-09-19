//
//  MacApplicationWindowController.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - macOS Application Window Controller

/// Generic native macOS window host.
///
/// This controller owns platform window mechanics only.
///
/// Product composition supplies:
///
/// - the root content controller
/// - window configuration
/// - an optional semantic toolbar adapter
///
/// It deliberately knows nothing about routes, scenes,
/// features, restoration, or application domain state.
@MainActor
public final class MacApplicationWindowController:
    NSWindowController {

    // MARK: - Platform Adapters

    public let toolbarAdapter:
        MacToolbarAdapter?


    // MARK: - Init

    public init(
        contentViewController:
            NSViewController,
        configuration:
            MacWindowConfiguration,
        toolbarAdapter:
            MacToolbarAdapter? = nil
    ) {

        self.toolbarAdapter =
            toolbarAdapter


        let window =
            MacApplicationWindowFactory
                .makeWindow(
                    contentViewController:
                        contentViewController,
                    configuration:
                        configuration
                )


        super.init(
            window:
                window
        )


        toolbarAdapter?
            .install(
                on:
                    window
            )
    }


    @available(
        *,
        unavailable
    )
    required init?(
        coder:
            NSCoder
    ) {

        fatalError(
            "init(coder:) is not supported."
        )
    }
}

#endif
