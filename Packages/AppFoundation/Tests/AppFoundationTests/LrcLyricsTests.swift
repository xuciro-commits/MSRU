//
//  LrcLyricsTests.swift
//  AppFoundationTests
//

import Testing
import Foundation
@testable import AppFoundation

struct LrcLyricsTests {

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
        #expect(doc.activeLineIndex(at: 10.0) == 1) // "词：周杰伦..."
        #expect(doc.activeLineIndex(at: 30.0) == 2) // "故事的小黄花"
        #expect(doc.activeLineIndex(at: 35.0) == 3) // "从出生那年就飘着"
        #expect(doc.activeLineIndex(at: 100.0) == 5) // Last line
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
