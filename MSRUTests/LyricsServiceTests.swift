//
//  LyricsServiceTests.swift
//  MSRUTests
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
struct LyricsServiceTests {

    @Test
    func resolveLyricsFromCompanionFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let audioURL = tempDir.appendingPathComponent("01 - Test Song.flac")
        try Data("dummy audio".utf8).write(to: audioURL)

        let lrcURL = tempDir.appendingPathComponent("01 - Test Song.lrc")
        let lrcContent = """
        [ti:Test Song]
        [ar:Test Artist]
        [00:00.00]Line 1
        [00:05.00]Line 2
        """
        try Data(lrcContent.utf8).write(to: lrcURL)

        let service = LyricsService(cacheDirectory: tempDir.appendingPathComponent("cache"))
        let doc = await service.resolveLyrics(
            title: "Test Song",
            artist: "Test Artist",
            fileURL: audioURL
        )

        let unwrapped = try #require(doc)
        #expect(unwrapped.isSynced)
        #expect(unwrapped.lines.count == 2)
        #expect(unwrapped.lines[0].text == "Line 1")
        #expect(unwrapped.lines[1].text == "Line 2")
    }

    @Test
    func resolveLyricsFromCache() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheDir = tempDir.appendingPathComponent("LyricsCache")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cachedFile = cacheDir.appendingPathComponent("Artist A - Title B.lrc")
        let lrcContent = """
        [00:10.00]Cached Lyric Line
        """
        try Data(lrcContent.utf8).write(to: cachedFile)

        let service = LyricsService(cacheDirectory: cacheDir)
        let doc = await service.resolveLyrics(
            title: "Title B",
            artist: "Artist A"
        )

        let unwrapped = try #require(doc)
        #expect(unwrapped.lines.count == 1)
        #expect(unwrapped.lines[0].text == "Cached Lyric Line")
    }

    @Test
    func lyricsStoreSyncUpdatesActiveLine() async throws {
        let store = LyricsStore()
        let lrcContent = """
        [00:00.00]Intro
        [00:10.00]Verse 1
        [00:20.00]Chorus
        """
        let doc = LrcParser.parse(lrcContent)

        #expect(doc.activeLineIndex(at: 5.0) == 0)
        #expect(doc.activeLineIndex(at: 12.0) == 1)
        #expect(doc.activeLineIndex(at: 25.0) == 2)
    }
}
