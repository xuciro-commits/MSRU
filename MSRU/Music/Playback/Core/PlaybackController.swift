//
//  PlaybackController.swift
//  MSRU
//

import AVFoundation
import Foundation
import Observation

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
protocol PlaybackSessionObserving: AnyObject {
    func playbackDidUpdateState(_ controller: PlaybackController)
    func playbackDidUpdateItem(_ controller: PlaybackController)
    func playbackDidSeek(_ controller: PlaybackController, to time: TimeInterval)
}

private struct WeakSessionObserver {
    weak var value: PlaybackSessionObserving?
}

@MainActor @Observable final class PlaybackController {

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

    let providerKernel: PlaybackProviderKernel

    // MARK: - Queue

    let playbackQueue: PlaybackQueueController

    // MARK: - Session Observers

    @ObservationIgnored
    private var sessionObservers: [WeakSessionObserver] = []

    func addSessionObserver(_ observer: PlaybackSessionObserving) {
        sessionObservers.removeAll { $0.value == nil }
        if !sessionObservers.contains(where: { $0.value === observer }) {
            sessionObservers.append(WeakSessionObserver(value: observer))
            observer.playbackDidUpdateItem(self)
            observer.playbackDidUpdateState(self)
        }
    }

    func removeSessionObserver(_ observer: PlaybackSessionObserving) {
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

    private(set) var currentResource: PlaybackResource?

    private(set) var currentProviderID: PlaybackProviderID?

    // MARK: - Playback State

    private(set) var isPlaying = false {
        didSet {
            if oldValue != isPlaying {
                notifyStateChanged()
            }
        }
    }

    private(set) var isResolving = false

    private(set) var currentTime: TimeInterval = 0

    private(set) var duration: TimeInterval = 0

    private(set) var playbackErrorMessage: String?

    // MARK: - Volume & Mute State

    let equalizer: EqualizerStore

    private(set) var volume: Float = 1.0

    private(set) var isMuted: Bool = false

    var effectiveVolume: Float {
        isMuted ? 0.0 : volume
    }

    // MARK: - Resolution State

    private var resolvingItem: PlaybackItem?

    private var failedItem: PlaybackItem?

    private var resolutionTask: Task<Void, Never>?

    private var activeResolutionID: UUID?

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

    private let makePlayer: (URL) -> AVPlayer

    #if os(macOS)
    let audioOutput: MacAudioOutputController
    #endif

    // MARK: - Init

    init(
        providerKernel: PlaybackProviderKernel? = nil,
        makePlayer: @escaping (URL) -> AVPlayer = { AVPlayer(url: $0) }
    ) {

        self.makePlayer = makePlayer

        self.providerKernel = providerKernel ?? PlaybackProviderKernel.standard()

        self.playbackQueue = PlaybackQueueController()
        self.equalizer = EqualizerStore()
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
    func selectOutputDevice(_ uid: String?) {
        player?.pause()
        pcmEngine?.stopOutput()
        audioOutput.select(uid)
        restartCurrentForOutputChange()
    }

    func setExclusiveOutput(_ enabled: Bool) {
        player?.pause()
        pcmEngine?.stopOutput()
        audioOutput.setExclusive(enabled)
        restartCurrentForOutputChange()
    }

    private func restartCurrentForOutputChange() {
        guard let currentItem, hasActiveTransport else { return }
        resolveAndStart(currentItem, resumeAt: currentTime, autoPlay: isPlaying)
    }
    #endif

    // MARK: - Current Item

    var currentItem: PlaybackItem? {

        playbackQueue.current?.item
    }

    private var displayItem: PlaybackItem? {

        currentItem ?? resolvingItem ?? failedItem
    }

    // MARK: - Local Track Projection

    var currentTrack: LocalTrack? {

        currentItem?.localTrack
    }

    var resolvingTrack: LocalTrack? {

        resolvingItem?.localTrack
    }

    var failedTrack: LocalTrack? {

        failedItem?.localTrack
    }

    // MARK: - Identity Resolution for Lyrics

    /// MusicBrainz Recording MBID for the currently playing track,
    /// resolved via the local acoustic fingerprint registry.
    /// Updated asynchronously by LyricsStore when the track changes.
    var currentRecordingMBID: String? = nil

    /// Subsonic remote song ID for the currently playing track.
    var currentSubsonicSongID: String? {
        currentItem?.subsonicSongID
    }

    // Typed convenience projection; PlaybackQueueController owns the queue.

    var queue: [LocalTrack] {

        playbackQueue.allItems.compactMap { queueItem in

            queueItem.item.localTrack
        }
    }

    // MARK: - Openverse Track Projection

    var openverseCurrentTrack: OpenverseAudio? {

        currentItem?.openverseTrack
    }

    var openverseQueue: [OpenverseAudio] {

        playbackQueue.allItems.compactMap { queueItem in

            queueItem.item.openverseTrack
        }
    }

    // MARK: - Radio Station Projection

    var radioCurrentStation: RadioStation? {

        currentItem?.radioStation
    }

    var isLiveStream: Bool {
        radioCurrentStation != nil
    }

    var radioQueue: [RadioStation] {

        playbackQueue.allItems.compactMap { queueItem in

            queueItem.item.radioStation
        }
    }

    // MARK: - Queue State

    var unifiedCanPrevious: Bool {

        playbackQueue.canPrevious
    }

    var unifiedCanNext: Bool {

        playbackQueue.canNext
    }

    // MARK: - Unified Metadata

    var unifiedTitle: String {

        displayItem?.title ?? "Nothing Playing"
    }

    var unifiedSubtitle: String {

        displayItem?.subtitle ?? "Choose a track from your library"
    }

    var unifiedArtworkURL: URL? {

        displayItem?.artworkURL
    }

    var unifiedArtworkData: Data? {

        displayItem?.artworkData
    }

    var unifiedArtworkReference: MediaImageReference? {

        displayItem?.artworkImageReference
    }

    var unifiedProviderLabel: String {

        displayItem?.providerLabel ?? "LOCAL"
    }

    var unifiedHasTrack: Bool {

        displayItem != nil
    }

    // MARK: - Audio Format Metadata

    var audioFormatInfo: AudioFormatInfo? {
        guard let item = displayItem else { return nil }

        switch item.payload {
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

    var progress: Double {

        guard duration > 0 else {

            return 0
        }

        return min(max(currentTime / duration, 0), 1)
    }

    // MARK: - Local UI State

    func state(for track: LocalTrack) -> TrackPlaybackState {

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

    func state(for openverse: OpenverseAudio) -> TrackPlaybackState {

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

    func state(for station: RadioStation) -> TrackPlaybackState {

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

    func play(_ item: PlaybackItem, context: [PlaybackItem]? = nil) {

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

    func play(_ track: LocalTrack, queue: [LocalTrack]? = nil) {

        let item = PlaybackItem(local: track)

        let context = queue?.map { track in

            PlaybackItem(local: track)
        }

        play(item, context: context)
    }

    // MARK: - Openverse Play

    func play(openverse track: OpenverseAudio, queue: [OpenverseAudio]? = nil) {

        let item = PlaybackItem(openverse: track)

        let context = queue?.map { track in

            PlaybackItem(openverse: track)
        }

        play(item, context: context)
    }

    // MARK: - Radio Play

    func play(radio station: RadioStation, queue: [RadioStation]? = nil) {

        let item = PlaybackItem(radio: station)

        let context = queue?.map { station in

            PlaybackItem(radio: station)
        }

        play(item, context: context)
    }


    // MARK: - Library Play

    func play(_ track: LibraryTrack, queue: [LibraryTrack]? = nil) {

        guard let item = PlaybackItem(library: track) else {
            return
        }

        let context = queue?.compactMap { track in
            PlaybackItem(library: track)
        }

        play(item, context: context)
    }

    // MARK: - Toggle Current

    func toggle() {

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

    func toggle(track: LocalTrack, queue: [LocalTrack]) {

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

    func toggle(track: LocalTrack) {

        let effectiveQueue = queue.isEmpty ? [track] : queue

        toggle(track: track, queue: effectiveQueue)
    }

    // MARK: - Toggle Openverse

    func toggle(openverse track: OpenverseAudio, queue: [OpenverseAudio]) {

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

    func toggle(openverse track: OpenverseAudio) {

        let effectiveQueue = openverseQueue.isEmpty ? [track] : openverseQueue

        toggle(openverse: track, queue: effectiveQueue)
    }

    // MARK: - Toggle Radio

    func toggle(radio station: RadioStation, queue: [RadioStation]) {

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

    func toggle(radio station: RadioStation) {

        let effectiveQueue = radioQueue.isEmpty ? [station] : radioQueue

        toggle(radio: station, queue: effectiveQueue)
    }

    // MARK: - Toggle Library

    func toggle(library track: LibraryTrack, queue: [LibraryTrack]? = nil) {

        guard let item = PlaybackItem(library: track) else {
            return
        }

        if currentItem?.id == item.id {

            if let queue {

                playbackQueue.start(
                    item,
                    context: queue.compactMap {
                        PlaybackItem(library: $0)
                    }
                )
                refreshPCMNext()
            }

            toggle()
            return
        }

        play(track, queue: queue)
    }

    func playQueuedItem(id: UUID) {
        guard let selected = playbackQueue.select(id: id) else { return }
        resolveAndStart(selected.item)
    }

    // MARK: - Queue Actions

    func playNext(_ item: PlaybackItem) {

        playbackQueue.playNext(item)
        refreshPCMNext()
    }

    func addToQueue(_ item: PlaybackItem) {

        playbackQueue.addToQueue(item)
        refreshPCMNext()
    }

    // MARK: - Local Queue Actions

    func playNext(_ track: LocalTrack) {

        playNext(PlaybackItem(local: track))
    }

    func addToQueue(_ track: LocalTrack) {

        addToQueue(PlaybackItem(local: track))
    }

    // MARK: - Openverse Queue Actions

    func playNext(openverse track: OpenverseAudio) {

        playNext(PlaybackItem(openverse: track))
    }

    func addToQueue(openverse track: OpenverseAudio) {

        addToQueue(PlaybackItem(openverse: track))
    }

    // MARK: - Radio Queue Actions

    func playNext(radio station: RadioStation) {

        playNext(PlaybackItem(radio: station))
    }

    func addToQueue(radio station: RadioStation) {

        addToQueue(PlaybackItem(radio: station))
    }

    // MARK: - Library Queue Actions

    func playNext(_ track: LibraryTrack) {

        guard let item = PlaybackItem(library: track) else {
            return
        }

        playNext(item)
    }

    func addToQueue(_ track: LibraryTrack) {

        guard let item = PlaybackItem(library: track) else {
            return
        }

        addToQueue(item)
    }

    // MARK: - Remove / Move Queue

    func removeUpcoming(id: UUID) {

        playbackQueue.removeUpcoming(id: id)
        refreshPCMNext()
    }

    func removeUpcoming(at offsets: IndexSet) {

        playbackQueue.removeUpcoming(at: offsets)
        refreshPCMNext()
    }

    func moveUpcoming(fromOffsets: IndexSet, toOffset: Int) {

        playbackQueue.moveUpcoming(fromOffsets: fromOffsets, toOffset: toOffset)
        refreshPCMNext()
    }

    /// Purges deleted tracks from current playback and queue. If current track was purged, advances or stops.
    func purgeTracks(withIDs ids: Set<String>, localURLs: Set<URL> = []) {
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

    func clearUpcoming() {

        playbackQueue.clearUpcoming()
        refreshPCMNext()
    }

    // MARK: - Previous

    func previous() {

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

    func next() {

        guard let next = playbackQueue.advanceNext() else {

            return
        }

        resolveAndStart(next.item)
    }

    // MARK: - Pause

    func pause() {

        player?.pause()

        pcmEngine?.pause()

        isPlaying = false
    }

    // MARK: - Seek

    func seek(toProgress progress: Double) {

        guard duration > 0 else {

            return
        }

        let clamped = min(max(progress, 0), 1)

        seek(to: duration * clamped)
    }

    func seek(to seconds: TimeInterval) {

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

    func setVolume(_ newVolume: Float) {
        let clamped = min(max(newVolume, 0.0), 1.0)
        volume = clamped
        if isMuted && clamped > 0 {
            isMuted = false
        }
        applyVolumeToActiveTransport()
    }

    func toggleMute() {
        isMuted.toggle()
        applyVolumeToActiveTransport()
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        applyVolumeToActiveTransport()
    }

    var equalizerStatus: String {
        guard equalizer.state.isEnabled else { return "Equalizer bypassed" }
        guard currentResource != nil else { return "Equalizer ready for PCM playback" }
        return pcmEngine != nil ? "Equalizer active on PCM" : "Equalizer unavailable for this stream"
    }

    #if os(macOS)
    var outputFormatSummary: String {
        audioOutput.formatSummary + (equalizer.state.isEnabled && pcmEngine != nil ? " · EQ active" : "")
    }
    #endif

    func setEqualizerEnabled(_ enabled: Bool) {
        equalizer.setEnabled(enabled)
        pcmEngine?.applyEqualizer(equalizer.state)
        if enabled, player != nil, let currentItem,
           currentItem.playbackRequest.source == .subsonic {
            resolveAndStart(currentItem, resumeAt: currentTime, autoPlay: isPlaying)
        }
    }

    func setEqualizerGain(_ gain: Float, band: Int) {
        equalizer.setGain(gain, band: band)
        pcmEngine?.applyEqualizer(equalizer.state)
    }

    func applyEqualizerPreset(_ id: String) {
        equalizer.applyPreset(id)
        pcmEngine?.applyEqualizer(equalizer.state)
    }

    func saveEqualizerPreset(named name: String) {
        _ = equalizer.saveCurrentPreset(named: name)
    }

    func deleteEqualizerPreset(_ id: String) {
        equalizer.deletePreset(id)
    }

    private func applyVolumeToActiveTransport() {
        let effectiveVolume = isMuted ? 0.0 : volume
        player?.volume = effectiveVolume
        player?.isMuted = isMuted
        pcmEngine?.volume = effectiveVolume
    }

    // MARK: - Restart

    func restart() {

        guard hasActiveTransport else {

            return
        }

        seek(to: 0)
    }

    // MARK: - Stop

    func stop() {

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

        currentTime = 0
        isPlaying = false
        notifyItemChanged()
    }

    // MARK: - Retry

    func retryLastFailedResolution() {

        guard let failedItem else {

            return
        }

        resolveAndStart(failedItem)
    }

    // MARK: - Resolve

    private func resolveAndStart(_ item: PlaybackItem, resumeAt: TimeInterval = 0, autoPlay: Bool = true) {

        currentRecordingMBID = nil
        cancelActiveResolution()

        tearDownActiveTransport()

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

                let resource = try await self.providerKernel.resolver.resolve(request)

                guard !Task.isCancelled, self.activeResolutionID == resolutionID else {
                    if case .decodedPCM(let pcm) = resource.transport {
                        await pcm.session.close()
                    }
                    return
                }

                do {
                    try self.activate(resource: resource, item: item, resumeAt: resumeAt, autoPlay: autoPlay)
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

    private func activate(resource: PlaybackResource, item: PlaybackItem, resumeAt: TimeInterval = 0, autoPlay: Bool = true) throws {

        /*
         无论上一个 Transport 是 AVPlayer
         还是 PCM，都只通过这一处退出。
         */

        tearDownActiveTransport()

        switch resource.transport {

        // MARK: Apple-native AVPlayer

        case .avPlayerURL(let resolvedURL):

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
                newPlayer.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600),
                               toleranceBefore: .zero, toleranceAfter: .zero)
            }
            if autoPlay { newPlayer.play() }
            isPlaying = autoPlay

        // MARK: Extended Codec → PCM → AVAudioEngine

        case .decodedPCM(let pcmResource):

            #if os(macOS)
            let outputRoute = try audioOutput.prepare(inputRate: pcmResource.format.sampleRate)
            let engine = try PCMPlaybackEngine(resource: pcmResource, outputDeviceID: outputRoute.deviceID, equalizer: equalizer.state)
            audioOutput.updateEngineRate(engine.outputSampleRate)
            #else
            let engine = try PCMPlaybackEngine(resource: pcmResource, equalizer: equalizer.state)
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
                self.notifyItemChanged()
                self.refreshPCMNext()
                print("Playback ▶︎", "[\(nextResource.providerID.rawValue)]", next.item.title)
            }

            pcmEngine = engine

            currentResource = resource

            currentProviderID = resource.providerID

            currentTime = resumeAt

            duration = resource.duration ?? pcmResource.format.duration ?? item.duration ?? 0

            startPCMTimeUpdates(engine)

            if resumeAt > 0 {
                Task { [weak self, weak engine] in
                    guard let self, let engine, self.pcmEngine === engine else { return }
                    do {
                        try await engine.seek(to: resumeAt)
                        guard self.pcmEngine === engine else { return }
                        if autoPlay { engine.play() }
                        self.refreshPCMNext(force: true)
                    } catch {
                        guard self.pcmEngine === engine else { return }
                        self.handleTransportFailure(error.localizedDescription)
                    }
                }
            } else if autoPlay {
                engine.play()
            }
            isPlaying = autoPlay

            refreshPCMNext()

        // MARK: Future Provider-native Transport

        case .providerNative(let providerID, _):

            throw PlaybackControllerError.nativeTransportNotSupported(providerID: providerID)
        }

        print("Playback ▶︎", "[\(resource.providerID.rawValue)]", item.title)
        notifyItemChanged()
    }

    // MARK: - Active Transport

    private var hasActiveTransport: Bool {

        player != nil || pcmEngine != nil
    }

    private func resumeActiveTransport() {

        player?.play()

        pcmEngine?.play()
    }

    private func tearDownActiveTransport() {

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
            previousPCMEngine.stopOutput()
            previousPCMEngine.onEnded = nil
            previousPCMEngine.onFailure = nil
            previousPCMEngine.onAdvanced = nil

            Task {

                await previousPCMEngine.close()
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

    var errorDescription: String? {

        switch self {

        case .nativeTransportNotSupported(let providerID):

            return "Native playback transport for \(providerID.rawValue) is not implemented yet."
        }
    }
}
