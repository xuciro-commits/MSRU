//
//  MacScrollViewModifiersTests.swift
//  AppFoundationUITests
//

#if os(macOS)

import AppKit
import Testing

@testable import AppFoundationUI


struct MacScrollViewModifiersTests {

    @Test
    @MainActor
    func suppressRemovesNativeScrollerOccupancy() {

        let scrollView =
            NSScrollView(
                frame:
                    NSRect(
                        x: 0,
                        y: 0,
                        width: 400,
                        height: 300
                    )
            )

        scrollView.hasVerticalScroller =
            true

        scrollView.hasHorizontalScroller =
            true

        scrollView.scrollerStyle =
            .legacy

        scrollView
            .tile()


        // Legacy scrollers carve out physical gutter from clipView bounds
        #expect(
            scrollView
                .contentView
                .frame
                .width
            <
            400
        )


        MacScrollIndicatorSuppressor
            .suppress(
                scrollView:
                    scrollView
            )


        // Invariant: Completely suppressing scroll indicators must remove layout occupancy
        #expect(
            scrollView
                .scrollerStyle
            ==
            .overlay
        )

        #expect(
            !scrollView
                .hasVerticalScroller
        )

        #expect(
            !scrollView
                .hasHorizontalScroller
        )

        #expect(
            scrollView
                .contentView
                .frame
                .size
            ==
            CGSize(
                width: 400,
                height: 300
            )
        )
    }
}

#endif
