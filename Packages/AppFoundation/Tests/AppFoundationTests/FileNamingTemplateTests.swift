//
//  FileNamingTemplateTests.swift
//  AppFoundationTests
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import Testing
@testable import AppFoundation

@MainActor
struct FileNamingTemplateTests {

    @Test
    func standardDefaultTemplateRendering() {
        let template = FileNamingTemplate()
        let result = template.render(
            artist: "周杰伦",
            album: "叶惠美",
            year: 2003,
            trackNumber: 4,
            title: "晴天",
            fileExtension: "flac"
        )

        #expect(result == "周杰伦/叶惠美 (2003)/04 - 晴天.flac")
    }

    @Test
    func missingYearFallsBackWithoutEmptyParens() {
        let template = FileNamingTemplate()
        let result = template.render(
            artist: "Adele",
            album: "21",
            year: nil,
            trackNumber: 1,
            title: "Rolling In The Deep",
            fileExtension: "m4a"
        )

        #expect(result == "Adele/21/01 - Rolling In The Deep.m4a")
    }

    @Test
    func illegalCharactersAreSanitized() {
        let template = FileNamingTemplate()
        let result = template.render(
            artist: "AC/DC",
            album: "Live: 1992 *Special Edition?",
            year: 1992,
            trackNumber: 1,
            title: "Thunderstruck <Remix> | Final",
            fileExtension: "mp3"
        )

        #expect(!result.contains("*"))
        #expect(!result.contains("?"))
        #expect(!result.contains("<"))
        #expect(!result.contains(">"))
        #expect(!result.contains("|"))
        #expect(result.contains("AC_DC"))
        #expect(result.contains("Thunderstruck _Remix_ _ Final.mp3"))
    }

    @Test
    func utf8ByteLengthTruncation() {
        let extremelyLongTitle = String(repeating: "超长歌曲名称测试代码", count: 30)
        let sanitized = FileNamingTemplate.sanitize(extremelyLongTitle)
        #expect(sanitized.utf8.count <= 255)
    }
}
