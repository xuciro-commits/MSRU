//
//  AppleMusicTransport.swift
//  MSRU
//

import Foundation
import MusicKit

/// Bridges MusicKit's `ApplicationMusicPlayer` into the `PlaybackController` lifecycle.
///
/// The controller owns one optional instance at a time, matching how it manages
/// `AVPlayer` or `PCMPlaybackEngine`. When the transport is active, the controller
/// delegates play/pause/seek/time-update to this object.
@MainActor
public final class AppleMusicTransport {

    // MARK: - Callbacks

    public var onEnded: (@MainActor () -> Void)?
    public var onTimeUpdated: (@MainActor (TimeInterval) -> Void)?

    // MARK: - State

    public private(set) var isActive = false

    public var currentTime: TimeInterval {
        ApplicationMusicPlayer.shared.playbackTime
    }

    // MARK: - Private

    private var timeUpdateTask: Task<Void, Never>?
    private var stateObservationTask: Task<Void, Never>?

    // MARK: - Init

    nonisolated public init() {}

    // MARK: - Lifecycle

    public func start(duration: TimeInterval = 0, autoPlay: Bool) async throws {
        isActive = true

        if autoPlay {
            try await ApplicationMusicPlayer.shared.play()
        }

        startTimeUpdates()
        startStateObservation(trackDuration: duration)
    }

    public func play() {
        Task { @MainActor in
            try? await ApplicationMusicPlayer.shared.play()
        }
    }

    public func pause() {
        ApplicationMusicPlayer.shared.pause()
    }

    public func seek(to time: TimeInterval) {
        ApplicationMusicPlayer.shared.playbackTime = time
        onTimeUpdated?(time)
    }

    public func stop() {
        ApplicationMusicPlayer.shared.stop()
        ApplicationMusicPlayer.shared.queue = []
        tearDown()
    }

    // MARK: - Time Updates

    private func startTimeUpdates() {
        timeUpdateTask?.cancel()
        timeUpdateTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isActive else { return }
                self.onTimeUpdated?(ApplicationMusicPlayer.shared.playbackTime)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    // MARK: - State Observation

    private func startStateObservation(trackDuration: TimeInterval) {
        stateObservationTask?.cancel()
        stateObservationTask = Task { @MainActor [weak self] in
            // Poll the player state to detect when playback ends.
            // Do NOT start with hasStartedPlaying = true to avoid premature skipping on launch.
            var hasStartedPlaying = false
            while !Task.isCancelled {
                guard let self, self.isActive else { return }
                let state = ApplicationMusicPlayer.shared.state
                let isPlaying = state.playbackStatus == .playing
                let currentTime = ApplicationMusicPlayer.shared.playbackTime

                if isPlaying || currentTime > 0.5 {
                    hasStartedPlaying = true
                }

                // Check for natural track end ONLY after playback has actually begun.
                // Pausing (.paused) must NEVER be treated as track end.
                if hasStartedPlaying {
                    let isQueueEmpty = ApplicationMusicPlayer.shared.queue.currentEntry == nil
                    let isStopped = state.playbackStatus == .stopped
                    let isNearEnd = trackDuration > 0 && currentTime >= max(trackDuration - 1.5, 0)

                    if isQueueEmpty || (isStopped && (isNearEnd || currentTime <= 0.5)) {
                        self.onEnded?()
                        return
                    }
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: - Teardown

    public func tearDown() {
        isActive = false
        timeUpdateTask?.cancel()
        timeUpdateTask = nil
        stateObservationTask?.cancel()
        stateObservationTask = nil
        onEnded = nil
        onTimeUpdated = nil
    }
}
