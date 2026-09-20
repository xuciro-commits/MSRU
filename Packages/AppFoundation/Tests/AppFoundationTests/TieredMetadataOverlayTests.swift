//
//  TieredMetadataOverlayTests.swift
//  AppFoundationTests
//

import Foundation
import Testing
@testable import AppFoundation

struct TieredMetadataOverlayTests {

    @Test
    func overlayResolvesInCascadingPriority() {
        // 1. Raw only
        var title = OverlayValue<String>(raw: "Original Track Name")
        #expect(title.resolved == "Original Track Name")
        #expect(title.activeSource == .raw)
        #expect(!title.isOverridden)
        #expect(!title.isEnriched)

        // 2. Canonical injected -> takes precedence over raw
        title.setCanonical("Canonical Title (MusicBrainz)")
        #expect(title.resolved == "Canonical Title (MusicBrainz)")
        #expect(title.activeSource == .canonical)
        #expect(!title.isOverridden)
        #expect(title.isEnriched)
        #expect(title.raw == "Original Track Name", "Raw tag must remain preserved")

        // 3. User override -> takes precedence over both
        title.setUserOverride("My Custom Title")
        #expect(title.resolved == "My Custom Title")
        #expect(title.activeSource == .user)
        #expect(title.isOverridden)

        // 4. Clear user override -> gracefully falls back to canonical
        title.clearUserOverride()
        #expect(title.resolved == "Canonical Title (MusicBrainz)")
        #expect(title.activeSource == .canonical)
        #expect(!title.isOverridden)

        // 5. Reset to raw -> clears both user and canonical
        title.setUserOverride("Temporary Edit")
        title.resetToRaw()
        #expect(title.resolved == "Original Track Name")
        #expect(title.activeSource == .raw)
        #expect(title.canonical == nil)
        #expect(title.user == nil)
    }

    @Test
    func overlayHandlesNumericAndOptionalValues() {
        var trackNumber = OverlayValue<Int>(raw: 4)
        #expect(trackNumber.resolved == 4)

        trackNumber.setCanonical(4)
        #expect(!trackNumber.isEnriched, "Canonical matching raw is not considered enriched")

        trackNumber.setUserOverride(14)
        #expect(trackNumber.resolved == 14)
        #expect(trackNumber.isOverridden)

        let empty = OverlayValue<String>()
        #expect(empty.resolved == nil)
        #expect(empty.activeSource == .none)
    }

    @Test
    func overlayCodableRoundtrip() throws {
        let value = OverlayValue<String>(
            raw: "Raw Title",
            canonical: "Canonical Title",
            user: "User Title"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OverlayValue<String>.self, from: data)

        #expect(decoded == value)
        #expect(decoded.raw == "Raw Title")
        #expect(decoded.canonical == "Canonical Title")
        #expect(decoded.user == "User Title")
        #expect(decoded.resolved == "User Title")
    }
}
