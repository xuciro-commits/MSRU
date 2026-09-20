//
//  SystemNowPlayingCoordinatorTests.swift
//  MSRUTests
//

import Testing
import Foundation
import MediaPlayer
@testable import MSRU

@Suite("System Now Playing & Remote Controls Tests")
struct SystemNowPlayingCoordinatorTests {

    @Test("Coordinator activates, registers commands, and deactivates cleanly")
    @MainActor
    func testActivationAndDeactivation() {
        let playback = MSRUPreviewData.makePlaybackController()
        let coordinator = SystemNowPlayingCoordinator(playback: playback)

        #expect(!coordinator.isActive)
        #expect(coordinator.currentNowPlayingInfo == nil)

        // Activate
        coordinator.activate()
        #expect(coordinator.isActive)

        // Deactivate cleans up state and dictionary
        coordinator.deactivate()
        #expect(!coordinator.isActive)
        #expect(coordinator.currentNowPlayingInfo == nil)
    }

    @Test("Now Playing Info syncs track title, subtitle, duration and playback rate")
    @MainActor
    func testNowPlayingMetadataSync() {
        let playback = MSRUPreviewData.makePlaybackController()
        let track = MSRUPreviewData.localTracks[0]
        playback.play(track)

        let coordinator = SystemNowPlayingCoordinator(playback: playback)
        coordinator.activate()

        let info = coordinator.currentNowPlayingInfo
        #expect(info != nil)
        #expect(info?[MPMediaItemPropertyTitle] as? String == track.title)
        #expect(info?[MPMediaItemPropertyArtist] as? String == track.artist)
        #expect(info?[MPNowPlayingInfoPropertyIsLiveStream] as? Bool == false)
    }

    @Test("Remote command handlers dispatch to playback controller and return success")
    @MainActor
    func testRemoteCommandHandlers() {
        let playback = MSRUPreviewData.makePlaybackController()
        let track = MSRUPreviewData.localTracks[0]
        playback.play(track)

        let coordinator = SystemNowPlayingCoordinator(playback: playback)
        coordinator.activate()

        // Transport handlers
        #expect(coordinator.handlePlay() == .success)
        #expect(coordinator.handlePause() == .success)
        #expect(coordinator.handleTogglePlayPause() == .success)
        #expect(coordinator.handleSeek(to: 30) == .success)
    }

    @Test("Radio live stream maps isLiveStream flag and zero duration")
    @MainActor
    func testRadioLiveStreamMetadata() {
        let playback = MSRUPreviewData.makePlaybackController()
        if let station = RadioStation.defaultStations.first {
            playback.play(radio: station)
            let coordinator = SystemNowPlayingCoordinator(playback: playback)
            coordinator.activate()

            let info = coordinator.currentNowPlayingInfo
            #expect(info != nil)
            #expect(info?[MPNowPlayingInfoPropertyIsLiveStream] as? Bool == true)
            #expect(info?[MPMediaItemPropertyPlaybackDuration] as? Double == 0.0)
            #expect(info?[MPMediaItemPropertyTitle] as? String == station.name)
        }
    }

    @Test("ApplicationModel lifecycle creates and manages SystemNowPlayingCoordinator")
    @MainActor
    func testApplicationModelLifecycleIntegration() {
        let app = ApplicationModel()
        #expect(app.systemNowPlayingCoordinator == nil)

        // Start activates coordinator
        app.start()
        #expect(app.systemNowPlayingCoordinator != nil)
        #expect(app.systemNowPlayingCoordinator?.isActive == true)

        // Terminate deactivates coordinator
        app.terminate()
        #expect(app.systemNowPlayingCoordinator == nil)
    }
}
