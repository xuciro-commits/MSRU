//
//  MacWindowConfiguration.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - macOS Window Configuration

/// Platform-level configuration for a standard application window.
///
/// This contains AppKit window mechanics only.
/// It intentionally knows nothing about application routes,
/// scenes, features, restoration, or product state.
@MainActor
public struct MacWindowConfiguration {

    public var title:
        String

    public var initialSize:
        NSSize

    public var minimumSize:
        NSSize

    public var toolbarStyle:
        NSWindow.ToolbarStyle

    public var titleVisibility:
        NSWindow.TitleVisibility

    public var titlebarAppearsTransparent:
        Bool

    public var titlebarSeparatorStyle:
        NSTitlebarSeparatorStyle

    public var centerOnCreation:
        Bool

    public var isReleasedWhenClosed:
        Bool


    public init(
        title:
            String,
        initialSize:
            NSSize = .init(
                width:
                    1200,
                height:
                    760
            ),
        minimumSize:
            NSSize = .init(
                width:
                    900,
                height:
                    600
            ),
        toolbarStyle:
            NSWindow.ToolbarStyle = .unified,
        titleVisibility:
            NSWindow.TitleVisibility = .hidden,
        titlebarAppearsTransparent:
            Bool = true,
        titlebarSeparatorStyle:
            NSTitlebarSeparatorStyle = .none,
        centerOnCreation:
            Bool = true,
        isReleasedWhenClosed:
            Bool = false
    ) {

        self.title =
            title

        self.initialSize =
            initialSize

        self.minimumSize =
            minimumSize

        self.toolbarStyle =
            toolbarStyle

        self.titleVisibility =
            titleVisibility

        self.titlebarAppearsTransparent =
            titlebarAppearsTransparent

        self.titlebarSeparatorStyle =
            titlebarSeparatorStyle

        self.centerOnCreation =
            centerOnCreation

        self.isReleasedWhenClosed =
            isReleasedWhenClosed
    }
}

#endif
