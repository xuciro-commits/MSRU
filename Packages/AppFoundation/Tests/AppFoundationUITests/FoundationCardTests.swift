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
}
