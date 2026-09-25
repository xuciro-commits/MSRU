//
//  PlaybackController.swift
//  MSRU
//

import AVFoundation
import Foundation
import Observation
import MusicDomain
import MusicLibrary

// MARK: - Playback Identity State (Low-frequency, isolated for UI collection/card observation)

public struct PlaybackIdentityState: Sendable, Equatable {
    public let currentTrackID: String?
    public let isPlaying: Bool

    public init(currentTrackID: String? = nil, isPlaying: Bool = false) {
        self.currentTrackID = currentTrackID
        self.isPlaying = isPlaying
    }
}

// MARK: - Playback Session Observer Protocol

@MainActor
public protocol PlaybackSessionObserving: AnyObject {
    func playbackDidUpdateState(_ controller: PlaybackController)
    func playbackDidUpdateItem(_ controller: PlaybackController)
    func playbackDidSeek(_ controller: PlaybackController, to time: TimeInterval)
}

private struct WeakSessionObserver {
    public weak var value: PlaybackSessionObserving?
}

@MainActor @Observable public final class PlaybackController {

    // MARK: - Identity State Projection
    public var identityState: PlaybackIdentityState {
        PlaybackIdentityState(currentTrackID: currentTrack?.id, isPlaying: isPlaying)
    }

    public func isPlaying(trackID: String) -> Bool {
        isPlaying && currentTrack?.id == trackID
    }

    public func isCurrent(trackID: String) -> Bool {
        currentTrack?.id == trackID
    }

    // MARK: - Provider Kernel

    public let providerKernel: PlaybackProviderKernel

    // MARK: - Queue

    public let playbackQueue: PlaybackQueueController

    // MARK: - Session Observers

    @ObservationIgnored
    private var sessionObservers: [WeakSessionObserver] = []

    public func addSessionObserver(_ observer: PlaybackSessionObserving) {
        sessionObservers.removeAll { $0.value == nil }
        if !sessionObservers.contains(where: { $0.value === observer }) {
            sessionObservers.append(WeakSessionObserver(value: observer))
            observer.playbackDidUpdateItem(self)
            observer.playbackDidUpdateState(self)
        }
    }

    public func removeSessionObserver(_ observer: PlaybackSessionObserving) {
        sessionObservers.removeAll { $0.value == nil || $0.value === observer }
    }

    private func notifyStateChanged() {
        sessionObservers.removeAll { $0.value == nil }
        for observer in sessionObservers {
            observer.value?.playbackDidUpdateState(self)
        }
    }

    private func notifyItemChanged() {
        sessionObservers.removeAll { $0.value == nil }
        for observer in sessionObservers {
            observer.value?.playbackDidUpdateItem(self)
        }
    }

    private func notifySeek(to time: TimeInterval) {
        sessionObservers.removeAll { $0.value == nil }
        for observer in sessionObservers {
            observer.value?.playbackDidSeek(self, to: time)
        }
    }

    // MARK: - Playback Resource

    public private(set) var currentResource: PlaybackResource?

    public private(set) var currentProviderID: PlaybackProviderID?

    // MARK: - Playback State

    public private(set) var isPlaying = false {
        didSet {
            if oldValue != isPlaying {
                notifyStateChanged()
            }
        }
    }

    public private(set) var isResolving = false

    public private(set) var currentTime: TimeInterval = 0

    public private(set) var duration: TimeInterval = 0

    public private(set) var playbackErrorMessage: String?
    private var localQueuePageSource: LocalPlaybackPageSource?
    private var localQueuePageTask: Task<Void, Never>?
    private var localQueueGeneration = UUID()
    private var advanceAfterQueuePage = false

    // MARK: - Volume & Mute State

    public let equalizer: EqualizerStore
    public let replayGainSettings: ReplayGainSettings
    private var activeLoudness: R128Measurement?
    private var loudnessAnalysisTask: Task<Void, Never>?
    private var loudnessAnalysisID: UUID?
    public private(set) var isAnalyzingLoudness = false
    public private(set) var loudnessMessage: String?

    public private(set) var volume: Float = 1.0

    public private(set) var isMuted: Bool = false

    public var effectiveVolume: Float {
        isMuted ? 0.0 : volume
    }

    // MARK: - Resolution State

    private var resolvingItem: PlaybackItem?

    private var failedItem: PlaybackItem?

    private var resolutionTask: Task<Void, Never>?

    private var activeResolutionID: UUID?
    private var resolvingResumeTime: TimeInterval = 0
    private var resolvingAutoPlay = true

    // MARK: - AVPlayer

    private var player: AVPlayer?

    private var timeObserver: Any?

    private var endObserver: NSObjectProtocol?

    private var statusObserver: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?

    // MARK: - Extended PCM Engine

    private var pcmEngine: PCMPlaybackEngine?

    private var pcmTimeTask: Task<Void, Never>?

    private var pcmNextResolutionTask: Task<Void, Never>?

    private var pcmNextTargetID: UUID?

    private var pcmShutdownTask: Task<Void, Never>?
    private var pcmShutdownSerial = 0
    private var pcmRecoveryAttempts: [Date] = []

    // MARK: - Apple Music Transport

    private var appleMusicTransport: AppleMusicTransport?

    private let makePlayer: (URL) -> AVPlayer

    #if os(macOS)
    public let audioOutput: MacAudioOutputController
    #endif

    // MARK: - History Tracking

    public var isHistoryTrackingEnabled: Bool

    // MARK: - Init

    public init(
        providerKernel: PlaybackProviderKernel? = nil,
        isHistoryTrackingEnabled: Bool = !AppDatabase.isRunningTests,
        makePlayer: @escaping (URL) -> AVPlayer = { AVPlayer(url: $0) }
    ) {
        self.isHistoryTrackingEnabled = isHistoryTrackingEnabled
        self.makePlayer = makePlayer

        self.providerKernel = providerKernel ?? PlaybackProviderKernel.standard()

        self.playbackQueue = PlaybackQueueController()
        self.equalizer = EqualizerStore()
        self.replayGainSettings = ReplayGainSettings()
        #if os(macOS)
        self.audioOutput = MacAudioOutputController()
        self.audioOutput.onSelectedDeviceLost = { [weak self] in
            self?.restartCurrentForOutputChange()
        }
        self.audioOutput.onDefaultDeviceChanged = { [weak self] in
            self?.restartCurrentForOutputChange()
        }
        #endif
    }

    #if os(macOS)
    public func selectOutputDevice(_ uid: String?) {
        pcmRecoveryAttempts.removeAll()
        guard let currentItem, hasActiveTransport || isResolving else {
            audioOutput.select(uid)
            return
        }
        let resumeAt = pcmEngine?.currentTime ?? appleMusicTransport?.currentTime ?? (isResolving ? resolvingResumeTime : currentTime)
        let autoPlay = isResolving ? resolvingAutoPlay : isPlaying
        resolveAndStart(currentItem, resumeAt: resumeAt, autoPlay: autoPlay) { [weak self] in
            self?.audioOutput.select(uid)
        }
    }

    public func setExclusiveOutput(_ enabled: Bool) {
        pcmRecoveryAttempts.removeAll()
        guard let currentItem, hasActiveTransport || isResolving else {
            audioOutput.setExclusive(enabled)
            return
        }
        let resumeAt = pcmEngine?.currentTime ?? appleMusicTransport?.currentTime ?? (isResolving ? resolvingResumeTime : currentTime)
        let autoPlay = isResolving ? resolvingAutoPlay : isPlaying
        resolveAndStart(currentItem, resumeAt: resumeAt, autoPlay: autoPlay) { [weak self] in
            self?.audioOutput.setExclusive(enabled)
        }
    }

    private func restartCurrentForOutputChange() {
        guard let currentItem, hasActiveTransport else { return }
        resolveAndStart(currentItem, resumeAt: currentTime, autoPlay: isPlaying)
    }
    #endif

    // MARK: - Current Item

    public var currentItem: PlaybackItem? {

        playbackQueue.current?.item
    }

    public var displayItem: PlaybackItem? {

        currentItem ?? resolvingItem ?? failedItem
    }

    // MARK: - Local Track Projection

    public var currentTrack: LocalTrack? {

        currentItem?.localTrack
    }

    public var resolvingTrack: LocalTrack? {

        resolvingItem?.localTrack
    }

    public var failedTrack: LocalTrack? {

        failedItem?.localTrack
    }

    // MARK: - Identity Resolution for Lyrics

    /// MusicBrainz Recording MBID for the currently playing track,
    /// resolved via the local acoustic fingerprint registry.
    /// Updated asynchronously by LyricsStore when the track changes.
    public var currentRecordingMBID: String? = nil

    /// Subsonic remote song ID for the currently playing track.
    public var currentSubsonicSongID: String? {
        currentItem?.subsonicSongID
    }

    // Typed convenience projection; PlaybackQueueController owns the queue.

    public var queue: [LocalTrack] {

        playbackQueue.allItems.compactMap { queueItem in

            queueItem.item.localTrack
        }
    }

    // MARK: - Openverse Track Projection

    public var openverseCurrentTrack: OpenverseAudio? {

        currentItem?.openverseTrack
    }

    public var openverseQueue: [OpenverseAudio] {

        playbackQueue.allItems.compactMap { queueItem in

            queueItem.item.openverseTrack
        }
    }

    // MARK: - Radio Station Projection

    public var radioCurrentStation: RadioStation? {

        currentItem?.radioStation
    }

    public var isLiveStream: Bool {
        radioCurrentStation != nil
    }

    public var radioQueue: [RadioStation] {

        playbackQueue.allItems.compactMap { queueItem in

            queueItem.item.radioStation
        }
    }

    // MARK: - Queue State

    public var unifiedCanPrevious: Bool {

        playbackQueue.canPrevious
    }

    public var unifiedCanNext: Bool {

        playbackQueue.canNext
    }

    // MARK: - Unified Metadata

    public var unifiedTitle: String {

        displayItem?.title ?? "Nothing Playing"
    }

    public var unifiedSubtitle: String {

        displayItem?.subtitle ?? "Choose a track from your library"
    }

    public var unifiedArtworkURL: URL? {

        displayItem?.artworkURL
    }

    public var unifiedArtworkData: Data? {

        displayItem?.artworkData
    }

    public var unifiedProviderLabel: String {

        displayItem?.providerLabel ?? "LOCAL"
    }

    public var unifiedHasTrack: Bool {

        displayItem != nil
    }

    // MARK: - Audio Format Metadata

    public var audioFormatInfo: AudioFormatInfo? {
        guard let item = displayItem else { return nil }

        switch item.payload {
        case .appleMusic:
            return AudioFormatInfo(
                codec: "AAC",
                sampleRate: "44.1 kHz",
                bitDepth: "16-bit",
                bitrate: "256 kbps",
                isLossless: false,
                isHiRes: false
            )

        case .local(let track):
            let ext = track.fileURL.pathExtension.uppercased()
            let codec = ext.isEmpty ? "AUDIO" : ext
            let isLossless = ["FLAC", "WAV", "AIFF", "AIF", "ALAC", "DTS"].contains(codec)

            var sampleRateText = "44.1 kHz"
            var isHiRes = false

            if case .decodedPCM(let pcm) = currentResource?.transport {
                let sr = pcm.format.sampleRate
                sampleRateText = String(format: "%.1f kHz", sr / 1000.0)
                isHiRes = sr > 48000
            }

            return AudioFormatInfo(
                codec: codec,
                sampleRate: sampleRateText,
                bitDepth: isLossless ? "24-bit" : "16-bit",
                bitrate: isLossless ? (codec == "FLAC" ? "710 kbps" : "1411 kbps") : "320 kbps",
                isLossless: isLossless,
                isHiRes: isHiRes
            )

        case .openverse(let track):
            let ext = track.mediaURL?.pathExtension.uppercased() ?? "MP3"
            let codec = ext.isEmpty ? "MP3" : ext
            return AudioFormatInfo(
                codec: codec,
                sampleRate: "44.1 kHz",
                bitDepth: "16-bit",
                bitrate: "320 kbps",
                isLossless: false,
                isHiRes: false
            )

        case .radio(let station):
            return AudioFormatInfo(
                codec: station.codec.uppercased(),
                sampleRate: "44.1 kHz",
                bitDepth: nil,
                bitrate: station.bitrateKbps.map { "\($0) kbps" } ?? "128 kbps",
                isLossless: false,
                isHiRes: false
            )

        case .subsonic:
            return AudioFormatInfo(
                codec: "STREAM",
                sampleRate: "44.1 kHz",
                bitDepth: "16-bit",
                bitrate: "Dynamic",
                isLossless: true,
                isHiRes: false
            )
        }
    }

    // MARK: - Progress

    public var progress: Double {

        guard duration > 0 else {

            return 0
        }

        return min(max(currentTime / duration, 0), 1)
    }

    // MARK: - Local UI State

    public func state(for track: LocalTrack) -> TrackPlaybackState {

        if resolvingTrack?.id == track.id {

            return .resolving
        }

        if failedTrack?.id == track.id, let playbackErrorMessage {

            return .failed(playbackErrorMessage)
        }

        guard currentTrack?.id == track.id else {

            return .idle
        }

        return isPlaying ? .playing : .paused
    }

    public func state(for openverse: OpenverseAudio) -> TrackPlaybackState {

        if resolvingItem?.openverseTrack?.id == openverse.id {

            return .resolving
        }

        if failedItem?.openverseTrack?.id == openverse.id, let playbackErrorMessage {

            return .failed(playbackErrorMessage)
        }

        guard openverseCurrentTrack?.id == openverse.id else {

            return .idle
        }

        return isPlaying ? .playing : .paused
    }

    public func state(for station: RadioStation) -> TrackPlaybackState {

        if resolvingItem?.radioStation?.id == station.id {

            return .resolving
        }

        if failedItem?.radioStation?.id == station.id, let playbackErrorMessage {

            return .failed(playbackErrorMessage)
        }

        guard radioCurrentStation?.id == station.id else {

            return .idle
        }

        return isPlaying ? .playing : .paused
    }

    // MARK: - Generic Play

    public func play(_ item: PlaybackItem, context: [PlaybackItem]? = nil) {

        clearPagedLocalQueue()

        let isAlreadyCurrent = currentItem?.id == item.id && currentResource != nil

        playbackQueue.start(item, context: context)

        if isAlreadyCurrent {

            refreshPCMNext()

            if duration > 0, currentTime >= duration - 0.25 {

                seek(toProgress: 0)
            }

            resumeActiveTransport()

            isPlaying = true

            return
        }

        resolveAndStart(item)
    }

    // MARK: - Local Play

    public func play(_ track: LocalTrack, queue: [LocalTrack]? = nil) {

        let item = PlaybackItem(local: track)

        let context = queue?.map { track in

            PlaybackItem(local: track)
        }

        play(item, context: context)
    }

    // MARK: - Openverse Play

    public func play(openverse track: OpenverseAudio, queue: [OpenverseAudio]? = nil) {

        let item = PlaybackItem(openverse: track)

        let context = queue?.map { track in

            PlaybackItem(openverse: track)
        }

        play(item, context: context)
    }

    // MARK: - Radio Play

    public func play(radio station: RadioStation, queue: [RadioStation]? = nil) {

        let item = PlaybackItem(radio: station)

        let context = queue?.map { station in

            PlaybackItem(radio: station)
        }

        play(item, context: context)
    }


    // MARK: - Library Play

    // MARK: - Toggle Current

    public func toggle() {

        if isResolving { return }

        guard hasActiveTransport else {

            if let currentItem {

                resolveAndStart(currentItem)
            }

            return
        }

        if isPlaying {

            pause()

            return
        }

        if duration > 0, currentTime >= duration - 0.25 {

            seek(toProgress: 0)
        }

        resumeActiveTransport()

        isPlaying = true
    }

    // MARK: - Toggle Local

    public func toggle(track: LocalTrack, queue: [LocalTrack]) {

        clearPagedLocalQueue()

        let item = PlaybackItem(local: track)

        if currentItem?.id == item.id {

            playbackQueue.start(
                item,
                context: queue.map {

                    PlaybackItem(local: $0)
                })

            refreshPCMNext()

            toggle()

            return
        }

        play(track, queue: queue)
    }

    public func toggle(track: LocalTrack) {

        let effectiveQueue = queue.isEmpty ? [track] : queue

        toggle(track: track, queue: effectiveQueue)
    }

    // MARK: - Toggle Openverse

    public func toggle(openverse track: OpenverseAudio, queue: [OpenverseAudio]) {

        let item = PlaybackItem(openverse: track)

        if currentItem?.id == item.id {

            playbackQueue.start(
                item,
                context: queue.map {

                    PlaybackItem(openverse: $0)
                })

            refreshPCMNext()

            toggle()

            return
        }

        play(openverse: track, queue: queue)
    }

    public func toggle(openverse track: OpenverseAudio) {

        let effectiveQueue = openverseQueue.isEmpty ? [track] : openverseQueue

        toggle(openverse: track, queue: effectiveQueue)
    }

    // MARK: - Toggle Radio

    public func toggle(radio station: RadioStation, queue: [RadioStation]) {

        let item = PlaybackItem(radio: station)

        if currentItem?.id == item.id {

            playbackQueue.start(
                item,
                context: queue.map {

                    PlaybackItem(radio: $0)
                })

            refreshPCMNext()

            toggle()

            return
        }

        play(radio: station, queue: queue)
    }

    public func toggle(radio station: RadioStation) {

        let effectiveQueue = radioQueue.isEmpty ? [station] : radioQueue

        toggle(radio: station, queue: effectiveQueue)
    }

    // MARK: - Toggle Library

    public func playQueuedItem(id: UUID) {
        guard let selected = playbackQueue.select(id: id) else { return }
        resolveAndStart(selected.item)
    }

    // MARK: - Queue Actions

    public func playNext(_ item: PlaybackItem) {

        playbackQueue.playNext(item)
        refreshPCMNext()
    }

    public func addToQueue(_ item: PlaybackItem) {

        playbackQueue.addToQueue(item)
        refreshPCMNext()
    }

    // MARK: - Local Queue Actions

    public func playNext(_ track: LocalTrack) {

        playNext(PlaybackItem(local: track))
    }

    public func addToQueue(_ track: LocalTrack) {

        addToQueue(PlaybackItem(local: track))
    }

    // MARK: - Openverse Queue Actions

    public func playNext(openverse track: OpenverseAudio) {

        playNext(PlaybackItem(openverse: track))
    }

    public func addToQueue(openverse track: OpenverseAudio) {

        addToQueue(PlaybackItem(openverse: track))
    }

    // MARK: - Radio Queue Actions

    public func playNext(radio station: RadioStation) {

        playNext(PlaybackItem(radio: station))
    }

    public func addToQueue(radio station: RadioStation) {

        addToQueue(PlaybackItem(radio: station))
    }

    // MARK: - Library Queue Actions

    // MARK: - Remove / Move Queue

    public func removeUpcoming(id: UUID) {

        playbackQueue.removeUpcoming(id: id)
        refreshPCMNext()
    }

    public func removeUpcoming(at offsets: IndexSet) {

        playbackQueue.removeUpcoming(at: offsets)
        refreshPCMNext()
    }

    public func moveUpcoming(fromOffsets: IndexSet, toOffset: Int) {

        playbackQueue.moveUpcoming(fromOffsets: fromOffsets, toOffset: toOffset)
        refreshPCMNext()
    }

    /// Purges deleted tracks from current playback and queue. If current track was purged, advances or stops.
    public func purgeTracks(withIDs ids: Set<String>, localURLs: Set<URL> = []) {
        guard !ids.isEmpty || !localURLs.isEmpty else { return }
        let currentAffected = playbackQueue.purgeItems { item in
            if ids.contains(item.id) { return true }
            if let local = item.localTrack {
                if ids.contains(local.id) || localURLs.contains(local.fileURL) || ids.contains(local.fileURL.path) || ids.contains(local.fileURL.standardizedFileURL.path) {
                    return true
                }
            }
            return false
        }
        if currentAffected {
            if playbackQueue.canNext {
                next()
            } else {
                stop()
            }
        } else {
            refreshPCMNext()
        }
    }

    public func clearUpcoming() {

        clearPagedLocalQueue()
        playbackQueue.clearUpcoming()
        refreshPCMNext()
    }

    // MARK: - Previous

    public func previous() {

        /*
         常见播放器行为：

         已经播放超过 3 秒，
         Previous = 回到当前歌曲开头。
         */

        if currentTime > 3 {

            restart()

            return
        }

        guard let previous = playbackQueue.movePrevious() else {

            restart()

            return
        }

        resolveAndStart(previous.item)
    }

    // MARK: - Next

    public func next() {

        guard let next = playbackQueue.advanceNext() else {
            if localQueuePageSource?.hasMore == true {
                advanceAfterQueuePage = true
                replenishLocalQueueIfNeeded()
            }
            return
        }

        if localQueuePageSource != nil {
            playbackQueue.trimHistory(keepingLast: 256)
        }
        resolveAndStart(next.item)
        replenishLocalQueueIfNeeded()
    }

    public func continueLocalQueue(using source: LocalPlaybackPageSource?) {
        localQueuePageSource = source
        replenishLocalQueueIfNeeded()
    }

    private func clearPagedLocalQueue() {
        localQueueGeneration = UUID()
        localQueuePageTask?.cancel()
        localQueuePageTask = nil
        localQueuePageSource = nil
        advanceAfterQueuePage = false
    }

    private func replenishLocalQueueIfNeeded() {
        guard let source = localQueuePageSource, source.hasMore,
              playbackQueue.upcoming.count < 16, localQueuePageTask == nil else { return }
        let generation = localQueueGeneration
        localQueuePageTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let tracks = try await source.nextPage()
                guard !Task.isCancelled, generation == self.localQueueGeneration else { return }
                for track in tracks {
                    self.playbackQueue.addToQueue(PlaybackItem(local: track))
                }
                self.localQueuePageTask = nil
                if self.advanceAfterQueuePage, self.playbackQueue.canNext {
                    self.advanceAfterQueuePage = false
                    self.next()
                } else {
                    self.replenishLocalQueueIfNeeded()
                }
            } catch {
                guard generation == self.localQueueGeneration else { return }
                self.localQueuePageTask = nil
                self.playbackErrorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Pause

    public func pause() {

        player?.pause()

        pcmEngine?.pause()

        appleMusicTransport?.pause()

        isPlaying = false
    }

    // MARK: - Seek

    public func seek(toProgress progress: Double) {

        guard duration > 0 else {

            return
        }

        let clamped = min(max(progress, 0), 1)

        seek(to: duration * clamped)
    }

    public func seek(to seconds: TimeInterval) {

        guard hasActiveTransport else {

            return
        }

        let upperBound = duration > 0 ? duration : seconds

        let clamped = min(max(seconds, 0), max(0, upperBound))

        currentTime = clamped
        notifySeek(to: clamped)

        // AVPlayer transport
        if let player {

            let time = CMTime(seconds: clamped, preferredTimescale: 600)

            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)

            return
        }

        // Apple Music transport
        if let appleMusicTransport {
            appleMusicTransport.seek(to: clamped)
            return
        }

        // Extended PCM transport
        if let pcmEngine {

            Task { [weak self] in

                guard let self, self.pcmEngine === pcmEngine else {

                    return
                }

                do {

                    try await pcmEngine.seek(to: clamped)

                    self.refreshPCMNext(force: true)

                } catch {

                    guard self.pcmEngine === pcmEngine else {

                        return
                    }

                    self.playbackErrorMessage = error.localizedDescription

                    self.isPlaying = false

                    print("PCM Seek ✕", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Volume & Mute Controls

    public func setVolume(_ newVolume: Float) {
        let clamped = min(max(newVolume, 0.0), 1.0)
        volume = clamped
        if isMuted && clamped > 0 {
            isMuted = false
        }
        applyVolumeToActiveTransport()
    }

    public func toggleMute() {
        isMuted.toggle()
        applyVolumeToActiveTransport()
    }

    public func setMuted(_ muted: Bool) {
        isMuted = muted
        applyVolumeToActiveTransport()
    }

    public var equalizerStatus: String {
        guard equalizer.state.isEnabled else { return "Equalizer bypassed" }
        guard currentResource != nil else { return "Equalizer ready for PCM playback" }
        return pcmEngine != nil ? "Equalizer active on PCM" : "Equalizer unavailable for this stream"
    }

    #if os(macOS)
    public var outputFormatSummary: String {
        audioOutput.formatSummary + (equalizer.state.isEnabled && pcmEngine != nil ? " · EQ active" : "")
    }
    #endif

    public func setEqualizerEnabled(_ enabled: Bool) {
        equalizer.setEnabled(enabled)
        pcmEngine?.applyEqualizer(equalizer.state)
        updateReplayGainOnEngine()
        if enabled, player != nil, let currentItem,
           currentItem.playbackRequest.source == .subsonic {
            resolveAndStart(currentItem, resumeAt: currentTime, autoPlay: isPlaying)
        }
    }

    public func setEqualizerGain(_ gain: Float, band: Int) {
        equalizer.setGain(gain, band: band)
        pcmEngine?.applyEqualizer(equalizer.state)
        updateReplayGainOnEngine()
    }

    public func applyEqualizerPreset(_ id: String) {
        equalizer.applyPreset(id)
        pcmEngine?.applyEqualizer(equalizer.state)
        updateReplayGainOnEngine()
    }

    public func saveEqualizerPreset(named name: String) {
        _ = equalizer.saveCurrentPreset(named: name)
    }

    public func deleteEqualizerPreset(_ id: String) {
        equalizer.deletePreset(id)
    }

    public func setReplayGainMode(_ mode: ReplayGainMode) {
        replayGainSettings.setMode(mode)
        guard let item = currentItem else {
            activeLoudness = nil
            updateReplayGainOnEngine()
            return
        }
        let itemID = item.id
        Task { [weak self] in
            guard let self else { return }
            let measurement = await self.cachedLoudness(for: item)
            guard self.currentItem?.id == itemID else { return }
            self.activeLoudness = measurement
            self.updateReplayGainOnEngine()
        }
    }

    public func analyzeCurrentLoudness(includeQueuedAlbum: Bool = false) {
        guard let current = currentItem?.localTrack else { return }
        loudnessAnalysisTask?.cancel()
        let urls: [URL]
        if includeQueuedAlbum, let album = current.album {
            let matched = playbackQueue.allItems.compactMap { $0.item.localTrack }.filter {
                $0.album == album && $0.artist == current.artist
            }
            urls = Array(Set(matched.map(\.fileURL)))
        } else {
            urls = [current.fileURL]
        }
        isAnalyzingLoudness = true
        loudnessMessage = nil
        let itemID = currentItem?.id
        let analysisID = UUID()
        loudnessAnalysisID = analysisID
        loudnessAnalysisTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                if includeQueuedAlbum {
                    _ = try await ReplayGainService.shared.analyzeAlbum(urls)
                } else {
                    _ = try await ReplayGainService.shared.analyzeTrack(current.fileURL)
                }
                try Task.checkCancellation()
                guard self.loudnessAnalysisID == analysisID else { return }
                self.loudnessMessage = "Loudness analysis complete"
                if self.currentItem?.id == itemID, let current = self.currentItem {
                    self.activeLoudness = await self.cachedLoudness(for: current)
                    self.updateReplayGainOnEngine()
                }
            } catch is CancellationError {
                if self.loudnessAnalysisID == analysisID {
                    self.loudnessMessage = "Loudness analysis cancelled"
                }
            } catch {
                if self.loudnessAnalysisID == analysisID {
                    self.loudnessMessage = error.localizedDescription
                }
            }
            if self.loudnessAnalysisID == analysisID {
                self.isAnalyzingLoudness = false
                self.loudnessAnalysisTask = nil
                self.loudnessAnalysisID = nil
            }
        }
    }

    public func cancelLoudnessAnalysis() {
        loudnessAnalysisTask?.cancel()
    }

    private func cachedLoudness(for item: PlaybackItem) async -> R128Measurement? {
        guard replayGainSettings.mode != .off, let track = item.localTrack else { return nil }
        do {
            if replayGainSettings.mode == .album,
               let album = try await ReplayGainService.shared.cachedAlbum(for: track.fileURL) {
                return album
            }
            return try await ReplayGainService.shared.cachedTrack(for: track.fileURL)
        } catch {
            return nil
        }
    }

    private func updateReplayGainOnEngine() {
        let eqGains = equalizer.state.isEnabled ? equalizer.state.gains : []
        pcmEngine?.setReplayGainDB(replayGainSettings.mode == .off ? 0 :
            ReplayGainPolicy.gainDB(for: activeLoudness, eqGains: eqGains))
    }

    private func applyVolumeToActiveTransport() {
        let effectiveVolume = isMuted ? 0.0 : volume
        player?.volume = effectiveVolume
        player?.isMuted = isMuted
        pcmEngine?.volume = effectiveVolume
    }

    // MARK: - Restart

    public func restart() {

        guard hasActiveTransport else {

            return
        }

        seek(to: 0)
    }

    // MARK: - Stop

    public func stop() {
        clearPagedLocalQueue()

        cancelActiveResolution()

        player?.pause()

        if let player {

            player.seek(to: .zero)
        }

        pcmEngine?.pause()

        if let pcmEngine {

            Task { [weak self] in

                guard let self, self.pcmEngine === pcmEngine else {

                    return
                }

                do {

                    try await pcmEngine.seek(to: 0)

                    self.refreshPCMNext(force: true)

                } catch {

                    print("PCM Stop Seek △", error.localizedDescription)
                }
            }
        }

        if let appleMusicTransport {

            appleMusicTransport.pause()
            appleMusicTransport.seek(to: 0)
        }

        currentTime = 0
        isPlaying = false
        notifyItemChanged()
    }

    // MARK: - Retry

    public func retryLastFailedResolution() {

        guard let failedItem else {

            return
        }

        pcmRecoveryAttempts.removeAll()
        resolveAndStart(failedItem)
    }

    // MARK: - Resolve

    private func resolveAndStart(
        _ item: PlaybackItem,
        resumeAt: TimeInterval = 0,
        autoPlay: Bool = true,
        afterShutdown: (@MainActor () -> Void)? = nil
    ) {

        currentRecordingMBID = nil
        resolvingResumeTime = resumeAt
        resolvingAutoPlay = autoPlay
        cancelActiveResolution()

        tearDownActiveTransport()
        let shutdown = pcmShutdownTask

        currentResource = nil

        currentProviderID = nil

        currentTime = 0

        duration = item.duration ?? 0

        isPlaying = false

        isResolving = true

        resolvingItem = item

        failedItem = nil

        playbackErrorMessage = nil

        let resolutionID = UUID()

        activeResolutionID = resolutionID

        let request = (playbackQueue.canNext || equalizer.state.isEnabled) && item.playbackRequest.source == .subsonic
            ? item.playbackRequest.preparingPCM()
            : item.playbackRequest

        resolutionTask = Task { [weak self] in

            guard let self else {

                return
            }

            do {

                await shutdown?.value
                guard !Task.isCancelled, self.activeResolutionID == resolutionID else { return }
                afterShutdown?()

                let resource = try await self.providerKernel.resolver.resolve(request)

                guard !Task.isCancelled, self.activeResolutionID == resolutionID else {
                    if case .decodedPCM(let pcm) = resource.transport {
                        await pcm.session.close()
                    }
                    return
                }

                do {
                    try await self.activate(resource: resource, item: item, resumeAt: resumeAt, autoPlay: autoPlay)
                } catch {
                    if case .decodedPCM(let pcm) = resource.transport {
                        await pcm.session.close()
                    }
                    throw error
                }

                self.isResolving = false

                self.resolvingItem = nil

                self.failedItem = nil

                self.activeResolutionID = nil

                self.resolutionTask = nil

            } catch is CancellationError {

                guard self.activeResolutionID == resolutionID else {

                    return
                }

                self.isResolving = false

                self.resolvingItem = nil

                self.activeResolutionID = nil

                self.resolutionTask = nil

            } catch {

                guard self.activeResolutionID == resolutionID else {

                    return
                }

                self.isResolving = false

                self.resolvingItem = nil

                self.failedItem = item

                self.activeResolutionID = nil

                self.resolutionTask = nil

                self.playbackErrorMessage = error.localizedDescription

                print("Playback Resolve ✕", error.localizedDescription)
            }
        }
    }

    // MARK: - Activate

    private func activate(resource: PlaybackResource, item: PlaybackItem, resumeAt: TimeInterval = 0, autoPlay: Bool = true) async throws {

        /*
         无论上一个 Transport 是 AVPlayer
         还是 PCM，都只通过这一处退出。
         */

        tearDownActiveTransport()

        switch resource.transport {

        // MARK: Apple-native AVPlayer

        case .avPlayerURL(let resolvedURL):

            activeLoudness = nil

            let newPlayer = makePlayer(resolvedURL)
            #if os(macOS)
            let outputRoute = try audioOutput.prepare(inputRate: nil)
            newPlayer.audioOutputDeviceUniqueID = outputRoute.deviceUID
            audioOutput.updateEngineRate(nil)
            #endif
            newPlayer.volume = isMuted ? 0.0 : volume
            newPlayer.isMuted = isMuted

            player = newPlayer

            currentResource = resource

            currentProviderID = resource.providerID

            currentTime = resumeAt

            duration = resource.duration ?? item.duration ?? 0

            installObservers(for: newPlayer)

            if resumeAt > 0 {
                await newPlayer.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600),
                                     toleranceBefore: .zero, toleranceAfter: .zero)
                guard !Task.isCancelled, player === newPlayer else { throw CancellationError() }
            }
            if autoPlay { newPlayer.play() }
            isPlaying = autoPlay

        // MARK: Extended Codec → PCM → AVAudioEngine

        case .decodedPCM(let pcmResource):

            let targetTime = max(0, resumeAt)
            if targetTime > 0 { try await pcmResource.session.seek(to: targetTime) }
            try Task.checkCancellation()
            let measurement = await cachedLoudness(for: item)
            try Task.checkCancellation()
            activeLoudness = measurement
            let eqGains = equalizer.state.isEnabled ? equalizer.state.gains : []
            let gainDB = replayGainSettings.mode == .off ? Float.zero :
                ReplayGainPolicy.gainDB(for: measurement, eqGains: eqGains)

            #if os(macOS)
            let outputRoute = try audioOutput.prepare(inputRate: pcmResource.format.sampleRate)
            let engine = try await PCMPlaybackEngine(resource: pcmResource, outputDeviceID: outputRoute.deviceID,
                                                     equalizer: equalizer.state, initialTime: targetTime,
                                                     replayGainDB: gainDB)
            audioOutput.updateEngineRate(engine.outputSampleRate)
            #else
            let engine = try await PCMPlaybackEngine(resource: pcmResource, equalizer: equalizer.state,
                                                     initialTime: targetTime, replayGainDB: gainDB)
            #endif
            engine.volume = isMuted ? 0.0 : volume

            engine.onEnded = { [weak self, weak engine] in
                guard let self, let engine, self.pcmEngine === engine else { return }
                self.handlePlaybackEnded()
            }

            engine.onFailure = { [weak self, weak engine] error in
                guard let self, let engine, self.pcmEngine === engine else { return }
                self.handleTransportFailure(error.localizedDescription)
            }

            engine.onConfigurationChanged = { [weak self, weak engine] in
                guard let self, let engine, self.pcmEngine === engine,
                      let currentItem = self.currentItem, !self.isResolving else { return }
                let now = Date()
                self.pcmRecoveryAttempts.removeAll { now.timeIntervalSince($0) > 10 }
                guard self.pcmRecoveryAttempts.count < 3 else {
                    self.handleTransportFailure("Audio output changed repeatedly. Select another output or retry.")
                    return
                }
                self.pcmRecoveryAttempts.append(now)
                self.resolveAndStart(currentItem, resumeAt: self.currentTime, autoPlay: self.isPlaying)
            }
            guard !Task.isCancelled, engine.isOutputRunning else {
                await engine.close()
                throw CancellationError()
            }

            engine.onAdvanced = { [weak self, weak engine] queueID, nextResource in
                guard let self, let engine, self.pcmEngine === engine else { return }
                guard self.playbackQueue.upcoming.first?.id == queueID,
                      let next = self.playbackQueue.advanceNext() else {
                    if self.playbackQueue.canNext { self.next() }
                    else { self.stop() }
                    return
                }
                self.currentRecordingMBID = nil
                self.currentResource = nextResource
                self.currentProviderID = nextResource.providerID
                self.currentTime = engine.currentTime
                #if os(macOS)
                let outputRate = engine.outputSampleRate
                if self.audioOutput.engineRate != outputRate {
                    self.audioOutput.updateEngineRate(outputRate)
                }
                #endif
                self.duration = engine.duration
                self.activeLoudness = nil
                engine.setReplayGainDB(0)
                let nextItem = next.item
                Task { [weak self, weak engine] in
                    guard let self, let engine else { return }
                    let result = await self.cachedLoudness(for: nextItem)
                    guard self.pcmEngine === engine, self.currentItem?.id == nextItem.id else { return }
                    self.activeLoudness = result
                    self.updateReplayGainOnEngine()
                }
                self.notifyItemChanged()
                self.refreshPCMNext()
                print("Playback ▶︎", "[\(nextResource.providerID.rawValue)]", next.item.title)
                self.recordPlaybackHistory(for: next.item)
            }

            pcmEngine = engine

            currentResource = resource

            currentProviderID = resource.providerID

            currentTime = resumeAt

            duration = resource.duration ?? pcmResource.format.duration ?? item.duration ?? 0

            startPCMTimeUpdates(engine)

            if autoPlay {
                engine.play()
            }
            isPlaying = autoPlay

            refreshPCMNext()

        // MARK: Apple Music / Provider-native Transport

        case .providerNative(let providerID, _):

            guard providerID == .appleMusic else {
                throw PlaybackControllerError.nativeTransportNotSupported(providerID: providerID)
            }

            activeLoudness = nil

            let transport = AppleMusicTransport()

            transport.onTimeUpdated = { [weak self, weak transport] time in
                guard let self, self.appleMusicTransport === transport else { return }
                self.currentTime = time
            }

            transport.onEnded = { [weak self, weak transport] in
                guard let self, self.appleMusicTransport === transport else { return }
                self.handlePlaybackEnded()
            }

            appleMusicTransport = transport

            currentResource = resource

            currentProviderID = resource.providerID

            currentTime = resumeAt

            duration = resource.duration ?? item.duration ?? 0

            try await transport.start(duration: duration, autoPlay: autoPlay)

            if resumeAt > 0 {
                transport.seek(to: resumeAt)
            }

            isPlaying = autoPlay
        }

        print("Playback ▶︎", "[\(resource.providerID.rawValue)]", item.title)
        notifyItemChanged()
        recordPlaybackHistory(for: item)
    }

    private func recordPlaybackHistory(for item: PlaybackItem) {
        guard isHistoryTrackingEnabled, !AppDatabase.isRunningTests else { return }
        let title = item.title
        let artist = item.subtitle
        let album = item.album
        let duration = item.duration ?? 0
        let artwork = item.artworkReference
        let fileURL: URL?
        switch item.payload {
        case .local(let track):
            fileURL = track.fileURL
        default:
            fileURL = nil
        }

        Task.detached(priority: .utility) {
            do {
                try await UserLibraryRepository().recordPlayback(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    artworkReference: artwork,
                    fileURL: fileURL
                )
            } catch {
                print("[PlaybackController] Failed to record playback: \(error)")
            }
        }
    }

    // MARK: - Active Transport

    private var hasActiveTransport: Bool {

        player != nil || pcmEngine != nil || appleMusicTransport != nil
    }

    private func resumeActiveTransport() {

        player?.play()

        pcmEngine?.play()

        appleMusicTransport?.play()
    }

    private func tearDownActiveTransport() {

        // Apple Music
        appleMusicTransport?.stop()
        appleMusicTransport = nil

        pcmNextResolutionTask?.cancel()
        pcmNextResolutionTask = nil
        pcmNextTargetID = nil
        pcmEngine?.clearPreparedNext()

        /*
         先移除 AVPlayer Observer，
         此时 player 仍然存在。
         */

        removeObservers()

        player?.pause()

        player = nil

        /*
         PCM 时间观察任务只属于当前 Engine。
         */

        pcmTimeTask?.cancel()

        pcmTimeTask = nil

        /*
         先从 Controller 移除引用，
         再异步关闭旧 Engine。

         这样旧 Engine 的异步关闭不会误伤
         后续刚建立的新 Engine。
         */

        let previousPCMEngine = pcmEngine

        pcmEngine = nil

        if let previousPCMEngine {
            previousPCMEngine.pause()
            previousPCMEngine.onEnded = nil
            previousPCMEngine.onFailure = nil
            previousPCMEngine.onAdvanced = nil
            previousPCMEngine.onConfigurationChanged = nil
            let earlier = pcmShutdownTask
            pcmShutdownSerial += 1
            let serial = pcmShutdownSerial
            let task = Task(priority: .userInitiated) {
                await earlier?.value
                await previousPCMEngine.close()
            }
            pcmShutdownTask = task
            Task { [weak self] in
                await task.value
                guard let self, self.pcmShutdownSerial == serial else { return }
                self.pcmShutdownTask = nil
            }
        }
    }

    private func refreshPCMNext(force: Bool = false) {
        let nextID = playbackQueue.upcoming.first?.id
        if !force, nextID == pcmNextTargetID { return }
        pcmNextResolutionTask?.cancel()
        pcmNextResolutionTask = nil
        guard let engine = pcmEngine else { return }
        if engine.hasPendingTransition {
            let time = engine.currentTime
            let shouldResume = isPlaying
            engine.pause()
            Task { [weak self, weak engine] in
                guard let self, let engine, self.pcmEngine === engine else { return }
                do {
                    try await engine.seek(to: time)
                    guard self.pcmEngine === engine else { return }
                    if shouldResume { engine.play() }
                    self.refreshPCMNext(force: true)
                } catch {
                    guard self.pcmEngine === engine else { return }
                    self.handleTransportFailure(error.localizedDescription)
                }
            }
            return
        }
        engine.clearPreparedNext()
        pcmNextTargetID = nextID
        guard let next = playbackQueue.upcoming.first else { return }
        let request = next.item.playbackRequest.preparingPCM()
        guard request.source == .local || request.source == .subsonic else { return }
        pcmNextResolutionTask = Task { [weak self, weak engine] in
            guard let self, let engine else { return }
            do {
                let resource = try await self.providerKernel.resolver.resolve(request)
                guard !Task.isCancelled,
                      self.pcmEngine === engine,
                      self.playbackQueue.upcoming.first?.id == next.id else {
                    if case .decodedPCM(let pcm) = resource.transport { await pcm.session.close() }
                    return
                }
                if engine.canPrepare(resource) {
                    engine.prepareNext(queueID: next.id, resource: resource)
                } else if case .decodedPCM(let pcm) = resource.transport {
                    await pcm.session.close()
                }
            } catch {
                // The current track keeps playing; the normal end path resolves the next item.
            }
        }
    }

    // MARK: - PCM Time Updates

    private func startPCMTimeUpdates(_ engine: PCMPlaybackEngine) {

        pcmTimeTask?.cancel()

        pcmTimeTask = Task { [weak self] in

            while !Task.isCancelled {

                do {

                    try await Task.sleep(nanoseconds: 250_000_000)

                } catch {

                    return
                }

                guard let self, self.pcmEngine === engine else {

                    return
                }

                self.currentTime = engine.currentTime

                if engine.duration > 0 {

                    self.duration = engine.duration
                }
            }
        }
    }

    // MARK: - Resolution Cancellation

    private func cancelActiveResolution() {

        resolutionTask?.cancel()

        resolutionTask = nil

        activeResolutionID = nil

        resolvingItem = nil

        isResolving = false
    }

    // MARK: - AVPlayer Observers

    private func installObservers(for player: AVPlayer) {

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)

        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self, weak player] time in

            let seconds = CMTimeGetSeconds(time)

            guard seconds.isFinite else {

                return
            }

            var resolvedDuration: TimeInterval?

            if let item = player?.currentItem {

                let value = CMTimeGetSeconds(item.duration)

                if value.isFinite, value > 0 {

                    resolvedDuration = value
                }
            }

            Task { @MainActor [weak self, weak player] in

                guard let self, let player, self.player === player else {

                    return
                }

                self.currentTime = seconds

                if let resolvedDuration {

                    self.duration = resolvedDuration
                }
            }
        }

        if let item = player.currentItem {
            statusObserver = item.observe(\.status, options: [.initial, .new]) {
                [weak self, weak player] item, _ in
                guard item.status == .failed else { return }
                let message = item.error?.localizedDescription ?? String(localized: "Unable to play this audio.")
                Task { @MainActor [weak self, weak player] in
                    guard let self, let player, self.player === player else { return }
                    self.handleTransportFailure(message)
                }
            }
            failureObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
            ) { [weak self, weak player] notification in
                let message =
                    (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?
                    .localizedDescription ?? String(localized: "Audio playback interrupted.")
                Task { @MainActor [weak self, weak player] in
                    guard let self, let player, self.player === player else { return }
                    self.handleTransportFailure(message)
                }
            }

            endObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
            ) { [weak self, weak player] _ in

                Task { @MainActor [weak self, weak player] in

                    guard let self, let player, self.player === player else { return }
                    self.handlePlaybackEnded()
                }
            }
        }
    }

    private func removeObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil

        if let timeObserver, let player {

            player.removeTimeObserver(timeObserver)
        }

        timeObserver = nil

        if let endObserver {

            NotificationCenter.default.removeObserver(endObserver)
        }

        endObserver = nil
    }

    private func handleTransportFailure(_ message: String) {
        failedItem = currentItem
        tearDownActiveTransport()
        currentResource = nil
        currentProviderID = nil
        isPlaying = false
        playbackErrorMessage = message
    }

    // MARK: - Playback End

    private func handlePlaybackEnded() {

        if playbackQueue.canNext {

            next()

            return
        }

        isPlaying = false

        currentTime = duration
    }
}

// MARK: - Errors

private enum PlaybackControllerError: LocalizedError {

    case nativeTransportNotSupported(providerID: PlaybackProviderID)

    public var errorDescription: String? {

        switch self {

        case .nativeTransportNotSupported(let providerID):

            return "Native playback transport for \(providerID.rawValue) is not implemented yet."
        }
    }
}

extension PlaybackController: LocalTrackRemovalObserver {}
