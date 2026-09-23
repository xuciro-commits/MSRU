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
            if Thread.isMainThread {
                return self?.handlePlay() ?? .commandFailed
            } else {
                return DispatchQueue.main.sync {
                    self?.handlePlay() ?? .commandFailed
                }
            }
        }
        commandTokens.append((commandCenter.playCommand, playToken))

        // Pause
        let pauseToken = commandCenter.pauseCommand.addTarget { [weak self] _ in
            if Thread.isMainThread {
                return self?.handlePause() ?? .commandFailed
            } else {
                return DispatchQueue.main.sync {
                    self?.handlePause() ?? .commandFailed
                }
            }
        }
        commandTokens.append((commandCenter.pauseCommand, pauseToken))

        // Toggle Play / Pause
        let toggleToken = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if Thread.isMainThread {
                return self?.handleTogglePlayPause() ?? .commandFailed
            } else {
                return DispatchQueue.main.sync {
                    self?.handleTogglePlayPause() ?? .commandFailed
                }
            }
        }
        commandTokens.append((commandCenter.togglePlayPauseCommand, toggleToken))

        // Next Track
        let nextToken = commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            if Thread.isMainThread {
                return self?.handleNext() ?? .commandFailed
            } else {
                return DispatchQueue.main.sync {
                    self?.handleNext() ?? .commandFailed
                }
            }
        }
        commandTokens.append((commandCenter.nextTrackCommand, nextToken))

        // Previous Track
        let prevToken = commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            if Thread.isMainThread {
                return self?.handlePrevious() ?? .commandFailed
            } else {
                return DispatchQueue.main.sync {
                    self?.handlePrevious() ?? .commandFailed
                }
            }
        }
        commandTokens.append((commandCenter.previousTrackCommand, prevToken))

        // Seek (Change Playback Position)
        let seekToken = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            if Thread.isMainThread {
                return self?.handleSeek(to: posEvent.positionTime) ?? .commandFailed
            } else {
                return DispatchQueue.main.sync {
                    self?.handleSeek(to: posEvent.positionTime) ?? .commandFailed
                }
            }
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

        if let artworkData = playback.unifiedArtworkData,
           let artwork = makeMediaItemArtwork(from: artworkData) {
            info[MPMediaItemPropertyArtwork] = artwork
        } else if let ref = playback.unifiedArtworkReference {
            Task { @MainActor [weak self] in
                guard let self, let image = await MediaImagePipeline.shared.loadThumbnail(for: ref, bucket: .px512) else { return }
                guard var currentInfo = self.nowPlayingCenter.nowPlayingInfo ?? self.currentNowPlayingInfo else { return }
                guard let artwork = makeMediaItemArtwork(from: image) else { return }
                currentInfo[MPMediaItemPropertyArtwork] = artwork
                self.nowPlayingCenter.nowPlayingInfo = currentInfo
                self.currentNowPlayingInfo = currentInfo
            }
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

// MARK: - Nonisolated Artwork Helper

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
private nonisolated func makeMediaItemArtwork(from data: Data) -> MPMediaItemArtwork? {
    guard let image = NSImage(data: data) else {
        return nil
    }
    return makeMediaItemArtwork(from: image)
}

private nonisolated func makeMediaItemArtwork(from image: NSImage) -> MPMediaItemArtwork? {
    guard image.size.width > 0, image.size.height > 0 else {
        return nil
    }
    let size = image.size
    return MPMediaItemArtwork(boundsSize: size) { _ in
        image
    }
}
#elseif canImport(UIKit)
private nonisolated func makeMediaItemArtwork(from data: Data) -> MPMediaItemArtwork? {
    guard let image = UIImage(data: data) else {
        return nil
    }
    return makeMediaItemArtwork(from: image)
}

private nonisolated func makeMediaItemArtwork(from image: UIImage) -> MPMediaItemArtwork? {
    guard image.size.width > 0, image.size.height > 0 else {
        return nil
    }
    let size = image.size
    return MPMediaItemArtwork(boundsSize: size) { _ in
        image
    }
}
#endif
