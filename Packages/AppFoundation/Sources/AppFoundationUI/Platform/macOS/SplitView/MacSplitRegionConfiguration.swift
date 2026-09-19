//
//  MacSplitRegionConfiguration.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - Split Region

public enum MacSplitRegion {

    case navigation
    case workspace
    case context
}


// MARK: - Accessory Edge

public enum MacSplitAccessoryEdge {

    case top
    case bottom
}


// MARK: - Region Configuration

/// Native sizing and layout policy for one macOS split region.
///
/// This type contains platform mechanics only.
/// It carries no application or feature semantics.
@MainActor
public struct MacSplitRegionConfiguration {

    public var canCollapse:
        Bool

    public var allowsFullHeightLayout:
        Bool

    public var minimumThickness:
        CGFloat

    public var maximumThickness:
        CGFloat?

    public var automaticallyAdjustsSafeAreaInsets:
        Bool


    public init(
        canCollapse:
            Bool,
        allowsFullHeightLayout:
            Bool = false,
        minimumThickness:
            CGFloat = 0,
        maximumThickness:
            CGFloat? = nil,
        automaticallyAdjustsSafeAreaInsets:
            Bool = true
    ) {

        self.canCollapse =
            canCollapse

        self.allowsFullHeightLayout =
            allowsFullHeightLayout

        self.minimumThickness =
            minimumThickness

        self.maximumThickness =
            maximumThickness

        self.automaticallyAdjustsSafeAreaInsets =
            automaticallyAdjustsSafeAreaInsets
    }


    func apply(
        to item:
            NSSplitViewItem
    ) {

        item.canCollapse =
            canCollapse

        item.allowsFullHeightLayout =
            allowsFullHeightLayout

        item.minimumThickness =
            minimumThickness

        if let maximumThickness {

            item.maximumThickness =
                maximumThickness
        }

        item.automaticallyAdjustsSafeAreaInsets =
            automaticallyAdjustsSafeAreaInsets
    }
}


// MARK: - Application Split Configuration

/// Platform configuration for a standard
/// Navigation | Workspace | Context macOS shell.
@MainActor
public struct MacApplicationSplitConfiguration {

    public var autosaveName:
        String?

    public var backgroundColor:
        NSColor?

    public var navigation:
        MacSplitRegionConfiguration

    public var workspace:
        MacSplitRegionConfiguration


    public init(
        autosaveName:
            String? = nil,
        backgroundColor:
            NSColor? = nil,
        navigation:
            MacSplitRegionConfiguration,
        workspace:
            MacSplitRegionConfiguration
    ) {

        self.autosaveName =
            autosaveName

        self.backgroundColor =
            backgroundColor

        self.navigation =
            navigation

        self.workspace =
            workspace
    }
}

#endif
