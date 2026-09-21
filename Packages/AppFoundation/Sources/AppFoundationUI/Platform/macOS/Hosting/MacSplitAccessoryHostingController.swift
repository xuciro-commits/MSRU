//
//  MacSplitAccessoryHostingController.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI


// MARK: - Split Accessory SwiftUI Hosting

/// Native AppKit bridge for placing SwiftUI content in an
/// NSSplitViewItem accessory region.
@MainActor
public final class MacSplitAccessoryHostingController<
    Content: View
>:
    NSSplitViewItemAccessoryViewController {

    private let hostingView:
        NSHostingView<Content>

    private let fixedHeight:
        CGFloat?


    public init(
        rootView:
            Content,
        height:
            CGFloat? = nil,
        automaticallyAppliesContentInsets:
            Bool = false
    ) {

        let host =
            NSHostingView(
                rootView:
                    rootView
            )

        if height != nil {
            host.sizingOptions = []
        }

        self.hostingView =
            host

        self.fixedHeight =
            height


        super.init(
            nibName:
                nil,
            bundle:
                nil
        )


        self.automaticallyAppliesContentInsets =
            automaticallyAppliesContentInsets

        preferredScrollEdgeEffectStyle =
            .soft
    }


    // MARK: - Content Update

    public func update(
        rootView:
            Content
    ) {

        hostingView.rootView =
            rootView
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


    public override func loadView() {

        if fixedHeight != nil {
            hostingView.sizingOptions = []
        }

        hostingView
            .translatesAutoresizingMaskIntoConstraints =
                false


        let container =
            NSView()

        container.addSubview(
            hostingView
        )


        NSLayoutConstraint.activate(
            [
                hostingView
                    .leadingAnchor
                    .constraint(
                        equalTo:
                            container
                                .leadingAnchor
                    ),

                hostingView
                    .trailingAnchor
                    .constraint(
                        equalTo:
                            container
                                .trailingAnchor
                    ),

                hostingView
                    .topAnchor
                    .constraint(
                        equalTo:
                            container
                                .topAnchor
                    ),

                hostingView
                    .bottomAnchor
                    .constraint(
                        equalTo:
                            container
                                .bottomAnchor
                    )
            ]
        )


        if let fixedHeight {

            let constraint =
                container
                    .heightAnchor
                    .constraint(
                        equalToConstant:
                            fixedHeight
                    )


            constraint.priority =
                .required

            constraint.isActive =
                true
        }


        view =
            container
    }
}

#endif
