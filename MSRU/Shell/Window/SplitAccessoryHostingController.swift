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


        /*
         Accessory 与普通 Pane 不同。

         它需要把自身理想高度报告给 AppKit，
         但不应该生成 min/max bounds，
         否则容易参与整个窗口的尺寸约束链。
         */
        self.hostingView.sizingOptions =
            [
                .intrinsicContentSize
            ]


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
