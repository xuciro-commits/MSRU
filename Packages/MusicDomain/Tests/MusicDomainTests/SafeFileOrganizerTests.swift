//
//  SafeFileOrganizerTests.swift
//  AppFoundationTests
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import Testing
@testable import MusicDomain

@MainActor
struct SafeFileOrganizerTests {

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

    @Test
    func generatePlanDetectsAndResolvesTargetConflicts() {
        let baseDir = URL(fileURLWithPath: "/music/organized")
        let source1 = URL(fileURLWithPath: "/downloads/01.flac")
        let source2 = URL(fileURLWithPath: "/temp/track1.flac")
        let desiredTarget = baseDir.appendingPathComponent("Jay Chou/04 - Sunny.flac")

        var simulatedDisk = Set<String>()
        let plan = SafeFileOrganizer.generatePlan(
            candidatePairs: [
                (source: source1, desiredTarget: desiredTarget, size: 1024),
                (source: source2, desiredTarget: desiredTarget, size: 2048)
            ],
            kind: .move,
            targetExistsChecker: { simulatedDisk.contains($0.path) }
        )

        #expect(plan.items.count == 2)
        #expect(plan.hasConflicts)
        #expect(plan.items[0].targetURL.lastPathComponent == "04 - Sunny.flac")
        #expect(plan.items[0].isConflict == false)
        #expect(plan.items[1].targetURL.lastPathComponent == "04 - Sunny (1).flac")
        #expect(plan.items[1].isConflict == true)
        #expect(plan.totalBytes == 3072)
    }

    @Test
    func dryRunSimulatesWithoutModifyingFiles() {
        let source = URL(fileURLWithPath: "/nonexistent/source.flac")
        let target = URL(fileURLWithPath: "/nonexistent/target.flac")
        let plan = FileOrganizationPlan(items: [
            FileMoveItem(sourceURL: source, targetURL: target, kind: .move, isConflict: false, fileSize: 500)
        ])

        let result = SafeFileOrganizer.execute(plan: plan, dryRun: true)
        #expect(result.isDryRun)
        #expect(result.isCompleteSuccess)
        #expect(result.executedItems.count == 1)
        #expect(result.failedItems.isEmpty)
    }

    @Test
    func physicalExecutionAndUndoRoundtrip() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFile = tempDir.appendingPathComponent("source.wav")
        let dummyData = "AudioDataTest".data(using: .utf8)!
        try dummyData.write(to: sourceFile)

        let targetDir = tempDir.appendingPathComponent("Organized/Artist/Album")
        let targetFile = targetDir.appendingPathComponent("01 - Test.wav")

        let plan = SafeFileOrganizer.generatePlan(
            candidatePairs: [(source: sourceFile, desiredTarget: targetFile, size: Int64(dummyData.count))],
            kind: .move
        )

        // Execute move
        let result = SafeFileOrganizer.execute(plan: plan, dryRun: false)
        #expect(result.isCompleteSuccess)
        #expect(!FileManager.default.fileExists(atPath: sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: targetFile.path))

        // Execute Undo
        try SafeFileOrganizer.undo(executedItems: result.executedItems)
        #expect(FileManager.default.fileExists(atPath: sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: targetFile.path))
    }
}
