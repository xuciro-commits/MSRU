//
//  NowPlayingCanvasTests.swift
//  MSRUTests
//

import Foundation
import Testing
import AppFoundation
import AppFoundationUI

@testable import MSRU

@MainActor
struct NowPlayingCanvasTests {

    // MARK: - Audio Format Info Tests

    @Test
    func audioFormatInfoSummaryFormatting() {
        let info = AudioFormatInfo(
            codec: "FLAC",
            sampleRate: "96.0 kHz",
            bitDepth: "24-bit",
            bitrate: "710 kbps",
            isLossless: true,
            isHiRes: true
        )

        #expect(info.codec == "FLAC")
        #expect(info.isLossless)
        #expect(info.isHiRes)
        #expect(info.summaryText == "FLAC • 710 kbps • 96.0 kHz")
    }

    @Test
    func playbackControllerAudioFormatDerivationForLocalTrack() {
        let controller = PlaybackController()
        #expect(controller.audioFormatInfo == nil)

        let flacTrack = LocalTrack(
            fileURL: URL(fileURLWithPath: "/Music/test.flac"),
            title: "Test FLAC",
            artist: "Artist",
            album: "Album",
            duration: 180,
            artworkData: nil
        )

        controller.play(flacTrack)
        guard let info = controller.audioFormatInfo else {
            Issue.record("Expected audioFormatInfo to be non-nil for local FLAC track")
            return
        }

        #expect(info.codec == "FLAC")
        #expect(info.isLossless)
        #expect(info.bitDepth == "24-bit")
        #expect(info.bitrate == "710 kbps")

        let mp3Track = LocalTrack(
            fileURL: URL(fileURLWithPath: "/Music/song.mp3"),
            title: "Test MP3",
            artist: "Artist",
            album: "Album",
            duration: 210,
            artworkData: nil
        )

        controller.play(mp3Track)
        guard let mp3Info = controller.audioFormatInfo else {
            Issue.record("Expected audioFormatInfo to be non-nil for local MP3 track")
            return
        }

        #expect(mp3Info.codec == "MP3")
        #expect(!mp3Info.isLossless)
        #expect(!mp3Info.isHiRes)
    }

    @Test
    func playbackControllerAudioFormatDerivationForRadioStation() {
        let controller = PlaybackController()
        let station = RadioStation(
            id: "kexp",
            name: "KEXP",
            description: "Music that matters",
            genre: .indie,
            streamURL: URL(string: "https://kexp.org/stream")!,
            codec: "AAC",
            bitrateKbps: 256
        )

        controller.play(radio: station)
        guard let info = controller.audioFormatInfo else {
            Issue.record("Expected audioFormatInfo for radio station")
            return
        }

        #expect(info.codec == "AAC")
        #expect(info.bitrate == "256 kbps")
        #expect(!info.isLossless)
    }

    // MARK: - SceneModel ContextPane 4-Mode Tests

    @Test
    func contextPaneCasesAndTitles() {
        let allCases = SceneModel.ContextPane.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.inspector))
        #expect(allCases.contains(.queue))
        #expect(allCases.contains(.visualizer))
        #expect(allCases.contains(.lyrics))

        #expect(SceneModel.ContextPane.inspector.title == "Details")
        #expect(SceneModel.ContextPane.queue.title == "Queue")
        #expect(SceneModel.ContextPane.visualizer.title == "Spectrum")
        #expect(SceneModel.ContextPane.lyrics.title == "Lyrics")
    }

    @Test
    func toggleContextPaneOpensClosesAndSwitchesTabs() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application, isQueuePresented: false)

        #expect(!scene.isQueuePresented)

        // 1. Toggling visualizer when closed opens it
        scene.toggleContextPane(.visualizer)
        #expect(scene.isQueuePresented)
        #expect(scene.activeContextPane == .visualizer)

        // 2. Toggling visualizer again closes it
        scene.toggleContextPane(.visualizer)
        #expect(!scene.isQueuePresented)

        // 3. Toggling lyrics when closed opens it
        scene.toggleContextPane(.lyrics)
        #expect(scene.isQueuePresented)
        #expect(scene.activeContextPane == .lyrics)

        // 4. Toggling queue while lyrics is open switches tab and stays open
        scene.toggleContextPane(.queue)
        #expect(scene.isQueuePresented)
        #expect(scene.activeContextPane == .queue)

        // 5. toggleQueue delegates to .queue
        scene.toggleQueue()
        #expect(!scene.isQueuePresented)
    }

    // MARK: - Immersive Canvas Presentation Tests

    @Test
    func nowPlayingCanvasPresentationLifecycleAndMultiSceneIsolation() {
        let application = MSRUPreviewData.makeApplication()
        let scene1 = SceneModel(application: application, isQueuePresented: false)
        let scene2 = SceneModel(application: application, isQueuePresented: false)

        #expect(!scene1.isNowPlayingPresented)
        #expect(!scene2.isNowPlayingPresented)

        // Toggle scene 1
        scene1.toggleNowPlaying()
        #expect(scene1.isNowPlayingPresented)
        #expect(!scene2.isNowPlayingPresented, "Scenes must maintain isolated now playing states")

        // Explicit set
        scene1.setNowPlaying(presented: false)
        #expect(!scene1.isNowPlayingPresented)

        scene2.setNowPlaying(presented: true)
        #expect(!scene1.isNowPlayingPresented)
        #expect(scene2.isNowPlayingPresented)

        // Closing scene resets presentation
        scene2.close()
        #expect(!scene2.isNowPlayingPresented)
    }
}
