//
//  MacSplitRegionConfiguration.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI

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
@MainActor
public struct MacSplitRegionConfiguration {
    public var canCollapse: Bool
    public var allowsFullHeightLayout: Bool
    public var minimumThickness: CGFloat
    public var maximumThickness: CGFloat?
    public var automaticallyAdjustsSafeAreaInsets: Bool

    public init(
        canCollapse: Bool,
        allowsFullHeightLayout: Bool = false,
        minimumThickness: CGFloat = 0,
        maximumThickness: CGFloat? = nil,
        automaticallyAdjustsSafeAreaInsets: Bool = true
    ) {
        self.canCollapse = canCollapse
        self.allowsFullHeightLayout = allowsFullHeightLayout
        self.minimumThickness = minimumThickness
        self.maximumThickness = maximumThickness
        self.automaticallyAdjustsSafeAreaInsets = automaticallyAdjustsSafeAreaInsets
    }

    func apply(to item: NSSplitViewItem) {
        item.canCollapse = canCollapse
        item.allowsFullHeightLayout = allowsFullHeightLayout
        item.minimumThickness = minimumThickness
        if let maximumThickness {
            item.maximumThickness = maximumThickness
        }
        item.automaticallyAdjustsSafeAreaInsets = automaticallyAdjustsSafeAreaInsets
    }
}

// MARK: - Application Split Configuration

/// Platform configuration for a standard
/// Navigation | Workspace | Context macOS shell.
@MainActor
public struct MacApplicationSplitConfiguration {
    public var autosaveName: String?
    public var backgroundColor: NSColor?
    public var navigation: MacSplitRegionConfiguration
    public var workspace: MacSplitRegionConfiguration

    public init(
        autosaveName: String? = nil,
        backgroundColor: NSColor? = nil,
        navigation: MacSplitRegionConfiguration,
        workspace: MacSplitRegionConfiguration
    ) {
        self.autosaveName = autosaveName
        self.backgroundColor = backgroundColor
        self.navigation = navigation
        self.workspace = workspace
    }
}

// MARK: - Split Hosting Controller

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

// MARK: - Mac Hosting Controller Factory

/// Creates SwiftUI hosting controllers suitable for AppKit-managed split-view geometry.
@MainActor
public enum MacHostingControllerFactory {
    public static func make<Content: View>(
        rootView: Content
    ) -> NSHostingController<Content> {
        let controller = MacSplitHostingController(rootView: rootView)
        controller.sizingOptions = []
        return controller
    }
}

// MARK: - Split Accessory SwiftUI Hosting

/// Native AppKit bridge for placing SwiftUI content in an NSSplitViewItem accessory region.
@MainActor
public final class MacSplitAccessoryHostingController<Content: View>: NSSplitViewItemAccessoryViewController {
    private let hostingView: NSHostingView<Content>
    private let fixedHeight: CGFloat?

    public init(
        rootView: Content,
        height: CGFloat? = nil,
        automaticallyAppliesContentInsets: Bool = false
    ) {
        let host = NSHostingView(rootView: rootView)
        if height != nil {
            host.sizingOptions = []
        }
        self.hostingView = host
        self.fixedHeight = height

        super.init(nibName: nil, bundle: nil)
        self.automaticallyAppliesContentInsets = automaticallyAppliesContentInsets
        preferredScrollEdgeEffectStyle = .soft
    }

    public func update(rootView: Content) {
        hostingView.rootView = rootView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
    }

    public override func loadView() {
        if fixedHeight != nil {
            hostingView.sizingOptions = []
        }
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        if let fixedHeight {
            let constraint = container.heightAnchor.constraint(equalToConstant: fixedHeight)
            constraint.priority = .required
            constraint.isActive = true
        }

        view = container
    }
}

#endif
