//
//  FoundationCardTests.swift
//  AppFoundationUITests
//
//  Created for the Application Foundation Framework.
//

import Testing
import SwiftUI
@testable import AppFoundationUI

struct FoundationCardTests {

    @Test
    @MainActor
    func testFoundationCardPropertiesAndCallback() {
        var selected = false

        let card = FoundationCard(
            titleText: "Abbey Road",
            subtitleText: "The Beatles",
            footerText: "1969",
            aspectRatio: 1.0,
            cornerRadius: 12.0,
            isSelected: true,
            onSelect: {
                selected = true
            }
        ) {
            Color.red
        }

        #expect(card.aspectRatio == 1.0)
        #expect(card.cornerRadius == 12.0)
        #expect(card.isSelected == true)

        card.onSelect()
        #expect(selected == true)
    }

    @Test
    @MainActor
    func testFoundationCardActionButton() {
        var triggered = false
        let button = FoundationCardActionButton(systemImage: "play.fill", title: "Play") {
            triggered = true
        }

        #expect(button.systemImage == "play.fill")
        #expect(button.title == "Play")

        button.action()
        #expect(triggered == true)
    }

    @Test
    @MainActor
    func testFoundationCardBadge() {
        let badge = FoundationCardBadge("LIVE", systemImage: "circle.fill")
        #expect(badge.text == "LIVE")
        #expect(badge.systemImage == "circle.fill")
    }

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
