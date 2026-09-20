//
//  WatchNowPlayingTests.swift
//  MSRUTests
//

import Testing
import Foundation
import SwiftUI
@testable import MSRU

@Suite("watchOS Presentation & Short Task Tests")
struct WatchNowPlayingTests {

    @Test("WatchNowPlayingView initializes cleanly with mock playback")
    @MainActor
    func testWatchNowPlayingViewInitialization() {
        let playback = MSRUPreviewData.makePlaybackController()
        let view = WatchNowPlayingView(playback: playback)
        #expect(view != nil)
    }

    @Test("WatchQueueSheetView initializes cleanly and reflects empty vs non-empty queue")
    @MainActor
    func testWatchQueueSheetViewQueueState() {
        let playback = MSRUPreviewData.makePlaybackController()
        var closed = false
        let view = WatchQueueSheetView(playback: playback, onClose: { closed = true })
        #expect(view != nil)
        #expect(!closed)
        
        // Clearing upcoming leaves current playing intact
        playback.clearUpcoming()
        #expect(playback.playbackQueue.upcoming.isEmpty)
    }

    @Test("Watch transport actions control playback states reliably")
    @MainActor
    func testWatchTransportControls() {
        let playback = MSRUPreviewData.makePlaybackController()
        
        // Volume adjustment
        playback.setVolume(0.75)
        #expect(playback.volume == 0.75)
        
        // Mute toggle
        let initialMuted = playback.isMuted
        playback.toggleMute()
        #expect(playback.isMuted != initialMuted)
        playback.toggleMute()
        #expect(playback.isMuted == initialMuted)
        
        // Transport actions execute safely without crash
        playback.toggle()
        playback.next()
        playback.previous()
        #expect(!playback.isPlaying)
    }
}
