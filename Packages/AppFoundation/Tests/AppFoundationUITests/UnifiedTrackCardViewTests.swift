//
//  UnifiedTrackCardViewTests.swift
//  AppFoundationUITests
//

import Testing
import SwiftUI
@testable import AppFoundationUI

struct UnifiedTrackCardViewTests {

    @Test
    @MainActor
    func testUnifiedTrackCardInitializationAndCallbacks() {
        var selected = false
        var played = false

        let card = UnifiedTrackCardView(
            title: "七里香",
            subtitle: "周杰伦",
            secondaryText: "七里香",
            durationText: "04:59",
            qualityBadge: "HI-RES",
            isPlaying: false,
            isSelected: true,
            onSelect: {
                selected = true
            },
            onPlay: {
                played = true
            }
        ) {
            Color.blue
        }

        #expect(card.title == "七里香")
        #expect(card.subtitle == "周杰伦")
        #expect(card.secondaryText == "七里香")
        #expect(card.durationText == "04:59")
        #expect(card.qualityBadge == "HI-RES")
        #expect(card.isSelected == true)
        #expect(card.isPlaying == false)

        card.onSelect()
        card.onPlay()

        #expect(selected == true)
        #expect(played == true)
    }
}
