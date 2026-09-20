//
//  SystemNowPlayingCoordinator.swift
//  MSRU
//

import Foundation
import MediaPlayer

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Remote Handling Protocol

@MainActor
protocol SystemMediaRemoteHandling: AnyObject {
    func handlePlay() -> MPRemoteCommandHandlerStatus
    func handlePause() -> MPRemoteCommandHandlerStatus
    func handleTogglePlayPause() -> MPRemoteCommandHandlerStatus
    func handleNext() -> MPRemoteCommandHandlerStatus
    func handlePrevious() -> MPRemoteCommandHandlerStatus
    func handleSeek(to position: TimeInterval) -> MPRemoteCommandHandlerStatus
}

// MARK: - System Now Playing Coordinator

/// System-level media controls and lock screen / Control Center synchronization coordinator.
/// Binds `PlaybackController` to `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter`.
@MainActor
final class SystemNowPlayingCoordinator: NSObject, PlaybackSessionObserving, SystemMediaRemoteHandling {

    // MARK: - Dependencies

    private weak var playback: PlaybackController?
    private let nowPlayingCenter: MPNowPlayingInfoCenter
    private let commandCenter: MPRemoteCommandCenter

    // MARK: - Command Tracking

    private var commandTokens: [(MPRemoteCommand, Any)] = []

    // MARK: - State

    private(set) var isActive: Bool = false
    private(set) var currentNowPlayingInfo: [String: Any]?

    // MARK: - Init

    init(
        playback: PlaybackController,
        nowPlayingCenter: MPNowPlayingInfoCenter = .default(),
        commandCenter: MPRemoteCommandCenter = .shared()
    ) {
        self.playback = playback
        self.nowPlayingCenter = nowPlayingCenter
        self.commandCenter = commandCenter
        super.init()
        playback.addSessionObserver(self)
    }

    // MARK: - Lifecycle

    func activate() {
        guard !isActive else { return }
        isActive = true
        registerCommands()
        updateNowPlayingInfo()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        unregisterCommands()
        nowPlayingCenter.nowPlayingInfo = nil
        currentNowPlayingInfo = nil
    }

    // MARK: - Command Registration

    private func registerCommands() {
        unregisterCommands()

        // Play
        let playToken = commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handlePlay() ?? .commandFailed
        }
        commandTokens.append((commandCenter.playCommand, playToken))

        // Pause
        let pauseToken = commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handlePause() ?? .commandFailed
        }
        commandTokens.append((commandCenter.pauseCommand, pauseToken))

        // Toggle Play / Pause
        let toggleToken = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handleTogglePlayPause() ?? .commandFailed
        }
        commandTokens.append((commandCenter.togglePlayPauseCommand, toggleToken))

        // Next Track
        let nextToken = commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.handleNext() ?? .commandFailed
        }
        commandTokens.append((commandCenter.nextTrackCommand, nextToken))

        // Previous Track
        let prevToken = commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.handlePrevious() ?? .commandFailed
        }
        commandTokens.append((commandCenter.previousTrackCommand, prevToken))

        // Seek (Change Playback Position)
        let seekToken = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            return self.handleSeek(to: posEvent.positionTime)
        }
        commandTokens.append((commandCenter.changePlaybackPositionCommand, seekToken))

        updateCommandsEnabled()
    }

    private func unregisterCommands() {
        for (command, token) in commandTokens {
            command.removeTarget(token)
        }
        commandTokens.removeAll()
    }

    // MARK: - SystemMediaRemoteHandling

    func handlePlay() -> MPRemoteCommandHandlerStatus {
        guard let playback else { return .noActionableNowPlayingItem }
        if !playback.isPlaying {
            playback.toggle()
        }
        return .success
    }

    func handlePause() -> MPRemoteCommandHandlerStatus {
        guard let playback else { return .noActionableNowPlayingItem }
        if playback.isPlaying {
            playback.pause()
        }
        return .success
    }

    func handleTogglePlayPause() -> MPRemoteCommandHandlerStatus {
        guard let playback else { return .noActionableNowPlayingItem }
        playback.toggle()
        return .success
    }

    func handleNext() -> MPRemoteCommandHandlerStatus {
        guard let playback else { return .noActionableNowPlayingItem }
        guard playback.unifiedCanNext else { return .noSuchContent }
        playback.next()
        return .success
    }

    func handlePrevious() -> MPRemoteCommandHandlerStatus {
        guard let playback else { return .noActionableNowPlayingItem }
        guard playback.unifiedCanPrevious else { return .noSuchContent }
        playback.previous()
        return .success
    }

    func handleSeek(to position: TimeInterval) -> MPRemoteCommandHandlerStatus {
        guard let playback else { return .noActionableNowPlayingItem }
        playback.seek(to: position)
        return .success
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo() {
        guard isActive else { return }
        guard let playback, playback.unifiedHasTrack else {
            nowPlayingCenter.nowPlayingInfo = nil
            currentNowPlayingInfo = nil
            updateCommandsEnabled()
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = playback.unifiedTitle
        info[MPMediaItemPropertyArtist] = playback.unifiedSubtitle

        if playback.isLiveStream {
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
            info[MPMediaItemPropertyPlaybackDuration] = 0.0
        } else {
            info[MPNowPlayingInfoPropertyIsLiveStream] = false
            if playback.duration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = playback.duration
            }
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playback.currentTime
        }

        info[MPNowPlayingInfoPropertyPlaybackRate] = playback.isPlaying ? 1.0 : 0.0

        if let artworkData = playback.unifiedArtworkData {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let image = NSImage(data: artworkData) {
                let size = image.size
                let artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
                info[MPMediaItemPropertyArtwork] = artwork
            }
            #elseif canImport(UIKit)
            if let image = UIImage(data: artworkData) {
                let size = image.size
                let artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
                info[MPMediaItemPropertyArtwork] = artwork
            }
            #endif
        }

        nowPlayingCenter.nowPlayingInfo = info
        currentNowPlayingInfo = info
        updateCommandsEnabled()
    }

    private func updateCommandsEnabled() {
        guard let playback else {
            commandCenter.playCommand.isEnabled = false
            commandCenter.pauseCommand.isEnabled = false
            commandCenter.togglePlayPauseCommand.isEnabled = false
            commandCenter.nextTrackCommand.isEnabled = false
            commandCenter.previousTrackCommand.isEnabled = false
            commandCenter.changePlaybackPositionCommand.isEnabled = false
            return
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = playback.unifiedCanNext
        commandCenter.previousTrackCommand.isEnabled = playback.unifiedCanPrevious
        commandCenter.changePlaybackPositionCommand.isEnabled = !playback.isLiveStream && playback.duration > 0
    }

    // MARK: - PlaybackSessionObserving

    func playbackDidUpdateState(_ controller: PlaybackController) {
        guard isActive else { return }
        guard var info = nowPlayingCenter.nowPlayingInfo ?? currentNowPlayingInfo else {
            updateNowPlayingInfo()
            return
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = controller.isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = controller.currentTime
        nowPlayingCenter.nowPlayingInfo = info
        currentNowPlayingInfo = info
        updateCommandsEnabled()
    }

    func playbackDidUpdateItem(_ controller: PlaybackController) {
        updateNowPlayingInfo()
    }

    func playbackDidSeek(_ controller: PlaybackController, to time: TimeInterval) {
        guard isActive else { return }
        guard var info = nowPlayingCenter.nowPlayingInfo ?? currentNowPlayingInfo else {
            updateNowPlayingInfo()
            return
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        info[MPNowPlayingInfoPropertyPlaybackRate] = controller.isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
        currentNowPlayingInfo = info
    }
}
