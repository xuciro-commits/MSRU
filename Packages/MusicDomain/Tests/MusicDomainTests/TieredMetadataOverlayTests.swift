//
//  TieredMetadataOverlayTests.swift
//  AppFoundationTests
//

import Foundation
import Testing
@testable import MusicDomain

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

    @Test
    func parseStandardSyncedLrc() {
        let lrcContent = """
        [ti:晴天]
        [ar:周杰伦]
        [al:叶惠美]
        [00:00.00]晴天 - 周杰伦
        [00:05.20]词：周杰伦 曲：周杰伦
        [00:29.50]故事的小黄花
        [00:32.80]从出生那年就飘着
        [00:36.40]童年的荡秋千
        [00:40.10]随记忆一直晃到现在
        """

        let doc = LrcParser.parse(lrcContent)
        #expect(doc.isSynced)
        #expect(doc.metadata["ti"] == "晴天")
        #expect(doc.metadata["ar"] == "周杰伦")
        #expect(doc.metadata["al"] == "叶惠美")
        #expect(doc.lines.count == 6)

        #expect(doc.lines[0].text == "晴天 - 周杰伦")
        #expect(doc.lines[0].timestamp == 0.0)

        #expect(doc.lines[2].text == "故事的小黄花")
        #expect(abs(doc.lines[2].timestamp - 29.5) < 0.01)

        // Time tracking
        #expect(doc.activeLineIndex(at: 10.0) == 1)
        #expect(doc.activeLineIndex(at: 30.0) == 2)
        #expect(doc.activeLineIndex(at: 35.0) == 3)
        #expect(doc.activeLineIndex(at: 100.0) == 5)
    }

    @Test
    func parseMultiTimestampLine() {
        let multi = """
        [00:10.00][00:20.00]Repeat chorus line
        """
        let doc = LrcParser.parse(multi)
        #expect(doc.lines.count == 2)
        #expect(doc.lines[0].timestamp == 10.0)
        #expect(doc.lines[0].text == "Repeat chorus line")
        #expect(doc.lines[1].timestamp == 20.0)
        #expect(doc.lines[1].text == "Repeat chorus line")
    }

    @Test
    func parseWithOffset() {
        let offsetLrc = """
        [offset:500]
        [00:01.00]Line 1
        """
        let doc = LrcParser.parse(offsetLrc)
        #expect(doc.lines.count == 1)
        #expect(abs(doc.lines[0].timestamp - 1.5) < 0.01)
    }
}
