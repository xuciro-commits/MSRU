#if os(macOS)

import AppKit
import SwiftUI


@MainActor
final class SplitAccessoryHostingController<
    Content: View
>:
    NSSplitViewItemAccessoryViewController {

    private let hostingView:
        NSHostingView<Content>


    init(
        rootView: Content
    ) {

        self.hostingView =
            NSHostingView(
                rootView:
                    rootView
            )


        super.init(
            nibName: nil,
            bundle: nil
        )


        automaticallyAppliesContentInsets =
            true

        preferredScrollEdgeEffectStyle =
            .soft
    }


    @available(
        *,
        unavailable
    )
    required init?(
        coder: NSCoder
    ) {

        fatalError(
            "init(coder:) is not supported."
        )
    }


    override func loadView() {

        view =
            hostingView
    }
}

#endif
