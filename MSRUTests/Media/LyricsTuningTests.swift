//
//  LyricsTuningTests.swift
//  MSRUTests
//
//  Unit tests for synchronized LRC lyrics timestamp calibration,
//  offset adjustment, formatting round-trip, sidecar export,
//  and embedded physical tag writeback (FLAC Vorbis comment LYRICS & MP3 ID3v2.4 USLT).
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU
import MusicDomain
import MusicLibrary
import MusicPlayback

@Suite("Lyrics Timestamp Tuning & Writeback")
@MainActor
struct LyricsTuningTests {

    // MARK: - Format & Offset Round-Trip

    @Test
    func lrcDocumentFormatLrcRoundTrip() {
        let originalLrc = """
        [ti:Blue Sky]
        [ar:The Horizon]
        [al:Atmosphere]
        [00:01.50]First line of the song
        [00:04.25]Second line of the song
        [00:10.00]Third line
        """

        let doc = LrcParser.parse(originalLrc)
        #expect(doc.isSynced)
        #expect(doc.metadata["ti"] == "Blue Sky")
        #expect(doc.metadata["ar"] == "The Horizon")
        #expect(doc.lines.count == 3)

        let formatted = doc.formatLrc()
        #expect(formatted.contains("[ti:Blue Sky]"))
        #expect(formatted.contains("[ar:The Horizon]"))
        #expect(formatted.contains("[00:01.50]First line of the song"))
        #expect(formatted.contains("[00:04.25]Second line of the song"))
        #expect(formatted.contains("[00:10.00]Third line"))

        // Re-parse formatted LRC and assert equivalence
        let reparsed = LrcParser.parse(formatted)
        #expect(reparsed.isSynced)
        #expect(reparsed.lines.count == 3)
        #expect(abs(reparsed.lines[0].timestamp - 1.50) < 0.02)
        #expect(reparsed.lines[0].text == "First line of the song")
        #expect(abs(reparsed.lines[1].timestamp - 4.25) < 0.02)
        #expect(abs(reparsed.lines[2].timestamp - 10.00) < 0.02)
    }

    @Test
    func lrcDocumentApplyingOffsetShiftsTimestampsAndClampsAtZero() {
        let lines = [
            LrcLine(timestamp: 1.0, text: "Intro"),
            LrcLine(timestamp: 3.5, text: "Verse"),
            LrcLine(timestamp: 8.0, text: "Chorus")
        ]
        let doc = LrcDocument(metadata: ["ti": "Test"], lines: lines, plainText: "Intro\nVerse\nChorus")

        // Advance timestamps by +0.5s
        let shiftedForward = doc.applyingOffset(0.5)
        #expect(abs(shiftedForward.lines[0].timestamp - 1.5) < 0.01)
        #expect(abs(shiftedForward.lines[1].timestamp - 4.0) < 0.01)
        #expect(abs(shiftedForward.lines[2].timestamp - 8.5) < 0.01)

        // Delay timestamps by -2.0s (clamping at >= 0.0s)
        let shiftedBackward = doc.applyingOffset(-2.0)
        #expect(shiftedBackward.lines[0].timestamp == 0.0) // 1.0 - 2.0 = -1.0 -> clamped to 0.0
        #expect(abs(shiftedBackward.lines[1].timestamp - 1.5) < 0.01) // 3.5 - 2.0 = 1.5
        #expect(abs(shiftedBackward.lines[2].timestamp - 6.0) < 0.01) // 8.0 - 2.0 = 6.0
    }

    // MARK: - LyricsStore Real-Time Tuning

    @Test
    @MainActor
    func lyricsStoreOffsetAdjustmentAndReset() {
        let store = LyricsStore()
        let playback = PlaybackController()

        #expect(store.timeOffset == 0.0)

        store.adjustOffset(by: 0.5, playback: playback)
        #expect(store.timeOffset == 0.5)

        store.adjustOffset(by: 0.5, playback: playback)
        #expect(store.timeOffset == 1.0)

        store.adjustOffset(by: -0.5, playback: playback)
        #expect(store.timeOffset == 0.5)

        store.resetOffset(playback: playback)
        #expect(store.timeOffset == 0.0)
    }

    // MARK: - Sidecar LRC Export

    @Test
    func audioTagWriterWritesSidecarLrcFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let audioURL = tempDir.appendingPathComponent("Track01.flac")
        try Data([0x00, 0x01, 0x02]).write(to: audioURL)

        let lrcContent = "[00:01.00]Hello world\n[00:03.00]Sidecar lyrics"
        let writer = AudioTagWriter()
        let writtenURL = try writer.writeSidecarLrc(to: audioURL, content: lrcContent)

        #expect(writtenURL.pathExtension == "lrc")
        #expect(writtenURL.lastPathComponent == "Track01.lrc")
        #expect(FileManager.default.fileExists(atPath: writtenURL.path))

        let readBack = try String(contentsOf: writtenURL, encoding: .utf8)
        #expect(readBack == lrcContent)
    }

    // MARK: - Embedded Audio Tags (FLAC Vorbis & MP3 ID3v2.4)

    @Test
    func audioTagWriterEmbedsLyricsInFLAC() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let flacURL = tempDir.appendingPathComponent("test.flac")

        // Construct minimal valid FLAC file (fLaC + 34-byte STREAMINFO block)
        var flacData = Data("fLaC".utf8)
        flacData.append(0x80) // isLast = true, type = 0 (STREAMINFO)
        flacData.append(contentsOf: [0x00, 0x00, 0x22]) // 34 bytes
        flacData.append(Data(repeating: 0x00, count: 34))
        try flacData.write(to: flacURL)

        let lyricsText = "[00:02.00]Embedded FLAC Lyrics\n[00:05.00]Second Line"
        var tags = AudioStandardTags(
            title: "FLAC Song",
            artist: "FLAC Artist",
            album: "FLAC Album"
        )
        tags.lyrics = lyricsText

        let writer = AudioTagWriter()
        _ = try await writer.writeTags(to: flacURL, tags: tags)

        let updatedData = try Data(contentsOf: flacURL)
        let updatedString = String(decoding: updatedData, as: UTF8.self)
        #expect(updatedString.contains("LYRICS=\(lyricsText)"))
    }

    @Test
    func audioTagWriterEmbedsLyricsInMP3() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mp3URL = tempDir.appendingPathComponent("test.mp3")

        // Minimal MP3 frame header
        let mp3Frame = Data([0xFF, 0xFB, 0x90, 0x64, 0x00, 0x00])
        try mp3Frame.write(to: mp3URL)

        let lyricsText = "[00:01.20]MP3 USLT Synchronized Lyrics"
        var tags = AudioStandardTags(
            title: "MP3 Song",
            artist: "MP3 Artist",
            album: "MP3 Album"
        )
        tags.lyrics = lyricsText

        let writer = AudioTagWriter()
        _ = try await writer.writeTags(to: mp3URL, tags: tags)

        let updatedData = try Data(contentsOf: mp3URL)
        // Verify ID3v2.4 header
        #expect(updatedData.starts(with: Data("ID3".utf8)))

        // Verify USLT frame identifier and lyrics presence
        let usltTag = Data("USLT".utf8)
        #expect(updatedData.range(of: usltTag) != nil)

        let lyricsData = Data(lyricsText.utf8)
        #expect(updatedData.range(of: lyricsData) != nil)
    }

    // MARK: - LyricsStore Writeback Integration

    @Test
    @MainActor
    func lyricsStoreSaveTunedLyricsWritesSidecarAndResetsOffset() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let audioURL = tempDir.appendingPathComponent("TunedTrack.wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)

        let lrcContent = """
        [ti:Tuned Song]
        [00:02.00]Line at 2s
        [00:06.00]Line at 6s
        """
        let doc = LrcParser.parse(lrcContent)

        let store = LyricsStore()
        let playback = PlaybackController()

        // Inject loaded document
        store.loadDocumentForTesting(doc, fileURL: audioURL, title: "Tuned Song", artist: "Tuned Artist")

        // Give task a moment or directly assign state for deterministic test
        store.adjustOffset(by: 0.5, playback: playback)
        #expect(store.timeOffset == 0.5)

        // Save tuning to sidecar
        try await store.saveTunedLyrics(audioURL: audioURL, writeSidecar: true, embedInAudio: false)

        // Verify offset is reset
        #expect(store.timeOffset == 0.0)
        #expect(store.lastSaveMessage == "Saved")

        // Verify sidecar .lrc exists
        let sidecarURL = tempDir.appendingPathComponent("TunedTrack.lrc")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        let savedLrc = try String(contentsOf: sidecarURL, encoding: .utf8)
        let reparsed = LrcParser.parse(savedLrc)
        #expect(reparsed.isSynced)
    }
}
