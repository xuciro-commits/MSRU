//
//  MenuBarPlayerTests.swift
//  MSRUTests
//
//  Canonical tests for macOS MenuBarExtra Status Item & Mini Controller.
//

#if os(macOS)

import MusicDomain
import MusicPlayback
import MusicLibrary
import Foundation
import Testing
import AppFoundation
import SwiftUI
@testable import MSRU

@Suite("macOS MenuBar Player Tests")
struct MenuBarPlayerTests {

    @MainActor
    @Test("MenuBarStatusItemLabel reflects playback state correctly")
    func menuBarStatusItemLabelPlaybackState() {
        let controller = PlaybackController()

        #expect(!controller.isPlaying)

        let label = MenuBarStatusItemLabel(playback: controller)
        #expect(label.playback.isPlaying == false)
    }

    @MainActor
    @Test("MenuBarPlayerView metadata projections with active track")
    func menuBarPlayerViewMetadataProjections() {
        let controller = PlaybackController()

        let track = LocalTrack(
            fileURL: URL(fileURLWithPath: "/music/test.flac"),
            title: "Night Flight",
            artist: "Lin Chuan",
            album: "Letters from the Mountain",
            duration: 252.0
        )
        let item = PlaybackItem(local: track)
        controller.playbackQueue.start(item, context: [item])

        #expect(controller.unifiedTitle == "Night Flight")
        #expect(controller.unifiedSubtitle == "Lin Chuan")
        #expect(controller.unifiedHasTrack == true)

        let playerView = MenuBarPlayerView(
            playback: controller,
            onOpenMainWindow: {},
            onQuitApp: {}
        )
        #expect(playerView.playback.unifiedTitle == "Night Flight")
    }

    @MainActor
    @Test("MenuBarPlayerView volume, mute and seek controls invoke controller correctly")
    func menuBarPlayerControls() {
        let controller = PlaybackController()

        // Volume control
        controller.setVolume(0.75)
        #expect(controller.volume == 0.75)

        // Mute toggle
        #expect(!controller.isMuted)
        controller.toggleMute()
        #expect(controller.isMuted)
        controller.toggleMute()
        #expect(!controller.isMuted)

        // Seek
        controller.seek(toProgress: 0.5)
    }

    @MainActor
    @Test("MenuBarPlayerView callbacks fire onOpenMainWindow and onQuitApp")
    func menuBarPlayerCallbacks() {
        let controller = PlaybackController()

        var didOpenMain = false
        var didQuit = false

        let view = MenuBarPlayerView(
            playback: controller,
            onOpenMainWindow: { didOpenMain = true },
            onQuitApp: { didQuit = true }
        )

        view.onOpenMainWindow?()
        #expect(didOpenMain == true)

        view.onQuitApp?()
        #expect(didQuit == true)
    }

    @MainActor
    @Test("AppDelegate exposes playback and window activation properly")
    func appDelegatePlaybackAndActivation() {
        let defaults = UserDefaults(suiteName: "test-app-delegate-\(UUID().uuidString)")!
        let app = ApplicationModel()
        let coordinator = MacSceneCoordinator(
            application: app,
            restorationStore: MacSceneRestorationStore(defaults: defaults),
            windowFactory: MainSceneWindowFactory(splitAutosaveName: nil)
        )
        let delegate = AppDelegate(sceneCoordinator: coordinator)

        #expect(delegate.playback === app.playback)
        #expect(coordinator.terminatesAfterLastWindowClosed == false)
    }
}

#endif
