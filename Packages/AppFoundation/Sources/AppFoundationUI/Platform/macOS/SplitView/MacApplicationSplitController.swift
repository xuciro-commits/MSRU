//
//  MacApplicationSplitController.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - macOS Application Split Controller

/// Native macOS shell for:
///
/// Navigation | Workspace | Context
///
/// This controller owns AppKit presentation mechanics only.
///
/// It does not know:
///
/// - application routes
/// - feature types
/// - SceneModel
/// - playback
/// - product view names
@MainActor
public final class MacApplicationSplitController:
    NSSplitViewController {

    // MARK: - Regions

    public let navigationItem:
        NSSplitViewItem

    public let workspaceItem:
        NSSplitViewItem

    public private(set) var contextItem:
        NSSplitViewItem?


    // MARK: - Configuration

    private let configuration:
        MacApplicationSplitConfiguration


    // MARK: - Presentation Events

    public var onContextPresentationChange:
        ((Bool) -> Void)?


    // MARK: - Init

    public init(
        navigationViewController:
            NSViewController,
        workspaceViewController:
            NSViewController,
        configuration:
            MacApplicationSplitConfiguration
    ) {

        self.configuration =
            configuration


        self.navigationItem =
            NSSplitViewItem(
                sidebarWithViewController:
                    navigationViewController
            )


        self.workspaceItem =
            NSSplitViewItem(
                viewController:
                    workspaceViewController
            )


        super.init(
            nibName:
                nil,
            bundle:
                nil
        )


        configuration
            .navigation
            .apply(
                to:
                    navigationItem
            )


        configuration
            .workspace
            .apply(
                to:
                    workspaceItem
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


    // MARK: - Lifecycle

    public override func viewDidLoad() {

        super.viewDidLoad()


        configureSplitView()


        addSplitViewItem(
            navigationItem
        )


        addSplitViewItem(
            workspaceItem
        )


        if let contextItem {

            addSplitViewItem(
                contextItem
            )
        }
    }


    // MARK: - Split View

    private func configureSplitView() {

        splitView.isVertical =
            true


        if let autosaveName =
            configuration
                .autosaveName {

            splitView.autosaveName =
                autosaveName
        }
    }


    // MARK: - Context Installation

    public func installContext(
        viewController:
            NSViewController,
        configuration:
            MacSplitRegionConfiguration,
        isPresented:
            Bool = true
    ) {

        if let existing =
            contextItem {

            if isViewLoaded {

                removeSplitViewItem(
                    existing
                )
            }
        }


        let item =
            NSSplitViewItem(
                inspectorWithViewController:
                    viewController
            )


        configuration.apply(
            to:
                item
        )


        item.isCollapsed =
            !isPresented


        contextItem =
            item


        if isViewLoaded {

            addSplitViewItem(
                item
            )
        }
    }


    // MARK: - Accessories

    public func addAccessory(
        _ accessory:
            NSSplitViewItemAccessoryViewController,
        to region:
            MacSplitRegion,
        edge:
            MacSplitAccessoryEdge
    ) {

        guard
            let item =
                item(
                    for:
                        region
                )
        else {

            assertionFailure(
                "Cannot attach an accessory to a missing split region."
            )

            return
        }


        switch edge {

        case .top:

            item
                .addTopAlignedAccessoryViewController(
                    accessory
                )


        case .bottom:

            item
                .addBottomAlignedAccessoryViewController(
                    accessory
                )
        }
    }


    private func item(
        for region:
            MacSplitRegion
    ) -> NSSplitViewItem? {

        switch region {

        case .navigation:

            navigationItem


        case .workspace:

            workspaceItem


        case .context:

            contextItem
        }
    }


    // MARK: - Navigation Presentation

    public func toggleNavigationPresentation() {

        toggleSidebar(
            nil
        )
    }


    // MARK: - Context Presentation

    public var isContextPresented:
        Bool {

        guard
            let contextItem
        else {

            return
                false
        }


        return
            !contextItem
                .isCollapsed
    }


    public func setContextPresented(
        _ isPresented:
            Bool
    ) {

        guard
            let contextItem
        else {

            return
        }


        contextItem.isCollapsed =
            !isPresented


        onContextPresentationChange?(
            isPresented
        )
    }


    public func toggleContextPresentation() {

        guard
            contextItem
            !=
            nil
        else {

            return
        }


        /*
         Context currently lands in AppKit's native inspector slot.

         Semantic meaning is intentionally independent:
         it may represent inspector, preview, activity, or utility.
         */

        toggleInspector(
            nil
        )


        onContextPresentationChange?(
            isContextPresented
        )
    }
}

#endif
