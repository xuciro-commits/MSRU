//
//  PlaybackController.swift
//  MSRU
//

import Foundation
import AVFoundation
import Observation


@MainActor
@Observable
final class PlaybackController {

    // MARK: - Provider Kernel

    let providerKernel:
        PlaybackProviderKernel


    // MARK: - Queue

    let playbackQueue:
        PlaybackQueueController


    // MARK: - Playback Resource

    private(set) var currentResource:
        PlaybackResource?

    private(set) var currentProviderID:
        PlaybackProviderID?


    // MARK: - Playback State

    private(set) var isPlaying =
        false

    private(set) var isResolving =
        false

    private(set) var currentTime:
        TimeInterval = 0

    private(set) var duration:
        TimeInterval = 0

    private(set) var playbackErrorMessage:
        String?


    // MARK: - Resolution State

    private var resolvingItem:
        PlaybackItem?

    private var failedItem:
        PlaybackItem?

    private var resolutionTask:
        Task<Void, Never>?

    private var activeResolutionID:
        UUID?


    // MARK: - AVPlayer

    private var player:
        AVPlayer?

    private var timeObserver:
        Any?

    private var endObserver:
        NSObjectProtocol?


    // MARK: - Extended PCM Engine

    private var pcmEngine:
        PCMPlaybackEngine?

    private var pcmTimeTask:
        Task<Void, Never>?


    // MARK: - Init

    init(
        providerKernel:
            PlaybackProviderKernel? = nil
    ) {

        self.providerKernel =
            providerKernel
            ?? PlaybackProviderKernel
                .standard()

        self.playbackQueue =
            PlaybackQueueController()
    }


    // MARK: - Current Item

    var currentItem:
        PlaybackItem? {

        playbackQueue
            .current?
            .item
    }


    private var displayItem:
        PlaybackItem? {

        currentItem
        ?? resolvingItem
        ?? failedItem
    }


    // MARK: - Compatibility: Active Source

    var activeSource:
        PlaybackActiveSource {

        guard
            let source =
                displayItem?
                    .source
        else {

            return .local
        }

        switch source {

        case .local:
            return .local

        case .openverse:
            return .openverse
        }
    }


    // MARK: - Compatibility: Local

    var currentTrack:
        LocalTrack? {

        currentItem?
            .localTrack
    }


    var resolvingTrack:
        LocalTrack? {

        resolvingItem?
            .localTrack
    }


    var failedTrack:
        LocalTrack? {

        failedItem?
            .localTrack
    }


    /*
     旧 UI 仍然可以读取 playback.queue。

     但真正的数据源已经变成：
     PlaybackQueueController。
     */

    var queue:
        [LocalTrack] {

        playbackQueue
            .allItems
            .compactMap {
                queueItem in

                queueItem
                    .item
                    .localTrack
            }
    }


    var currentIndex:
        Int? {

        guard
            let currentTrack
        else {

            return nil
        }

        return queue
            .firstIndex {
                track in

                track.id
                    == currentTrack.id
            }
    }


    var upNextTracks:
        [LocalTrack] {

        playbackQueue
            .upcoming
            .compactMap {
                queueItem in

                queueItem
                    .item
                    .localTrack
            }
    }


    // MARK: - Compatibility: Openverse

    var openverseCurrentTrack:
        OpenverseAudio? {

        currentItem?
            .openverseTrack
    }


    var openverseQueue:
        [OpenverseAudio] {

        playbackQueue
            .allItems
            .compactMap {
                queueItem in

                queueItem
                    .item
                    .openverseTrack
            }
    }


    var openverseCurrentIndex:
        Int? {

        guard
            let current =
                openverseCurrentTrack
        else {

            return nil
        }

        return openverseQueue
            .firstIndex {
                track in

                track.id
                    == current.id
            }
    }


    var openverseUpNextTracks:
        [OpenverseAudio] {

        playbackQueue
            .upcoming
            .compactMap {
                queueItem in

                queueItem
                    .item
                    .openverseTrack
            }
    }


    // MARK: - Queue State

    var canGoPrevious:
        Bool {

        playbackQueue
            .canPrevious
    }


    var canGoNext:
        Bool {

        playbackQueue
            .canNext
    }


    var unifiedCanPrevious:
        Bool {

        playbackQueue
            .canPrevious
    }


    var unifiedCanNext:
        Bool {

        playbackQueue
            .canNext
    }


    // MARK: - Unified Metadata

    var unifiedTitle:
        String {

        displayItem?
            .title
        ?? "Nothing Playing"
    }


    var unifiedSubtitle:
        String {

        displayItem?
            .subtitle
        ?? "Choose a track from your library"
    }


    var unifiedArtworkURL:
        URL? {

        displayItem?
            .artworkURL
    }


    var unifiedArtworkData:
        Data? {

        displayItem?
            .artworkData
    }


    var unifiedProviderLabel:
        String {

        displayItem?
            .providerLabel
        ?? "LOCAL"
    }


    var unifiedHasTrack:
        Bool {

        displayItem != nil
    }


    // MARK: - Progress

    var progress:
        Double {

        guard
            duration > 0
        else {

            return 0
        }

        return min(
            max(
                currentTime
                    / duration,
                0
            ),
            1
        )
    }


    // MARK: - Local UI State

    var displayTrack:
        LocalTrack? {

        currentTrack
        ?? resolvingTrack
        ?? failedTrack
    }


    var displayState:
        TrackPlaybackState {

        guard
            let displayTrack
        else {

            return .idle
        }

        return state(
            for:
                displayTrack
        )
    }


    func state(
        for track:
            LocalTrack
    ) -> TrackPlaybackState {

        if resolvingTrack?
            .id
            == track.id {

            return .resolving
        }

        if failedTrack?
            .id
            == track.id,
           let playbackErrorMessage {

            return .failed(
                playbackErrorMessage
            )
        }

        guard
            currentTrack?
                .id
                == track.id
        else {

            return .idle
        }

        return isPlaying
            ? .playing
            : .paused
    }


    func state(
        for openverse:
            OpenverseAudio
    ) -> TrackPlaybackState {

        if resolvingItem?
            .openverseTrack?
            .id
            == openverse.id {

            return .resolving
        }

        if failedItem?
            .openverseTrack?
            .id
            == openverse.id,
           let playbackErrorMessage {

            return .failed(
                playbackErrorMessage
            )
        }

        guard
            openverseCurrentTrack?
                .id
                == openverse.id
        else {

            return .idle
        }

        return isPlaying
            ? .playing
            : .paused
    }


    // MARK: - Generic Play

    func play(
        _ item:
            PlaybackItem,
        context:
            [PlaybackItem]? = nil
    ) {

        let isAlreadyCurrent =
            currentItem?
                .id
            == item.id
            &&
            currentResource
                != nil


        playbackQueue
            .start(
                item,
                context:
                    context
            )


        if isAlreadyCurrent {

            if duration > 0,
               currentTime
                >= duration - 0.25 {

                seek(
                    toProgress:
                        0
                )
            }

            resumeActiveTransport()

            isPlaying =
                true

            return
        }


        resolveAndStart(
            item
        )
    }


    // MARK: - Local Play

    func play(
        _ track:
            LocalTrack,
        queue:
            [LocalTrack]? = nil
    ) {

        let item =
            PlaybackItem(
                local:
                    track
            )


        let context =
            queue?
                .map {
                    track in

                    PlaybackItem(
                        local:
                            track
                    )
                }


        play(
            item,
            context:
                context
        )
    }


    // MARK: - Openverse Play

    func play(
        openverse track:
            OpenverseAudio,
        queue:
            [OpenverseAudio]? = nil
    ) {

        let item =
            PlaybackItem(
                openverse:
                    track
            )


        let context =
            queue?
                .map {
                    track in

                    PlaybackItem(
                        openverse:
                            track
                    )
                }


        play(
            item,
            context:
                context
        )
    }


    // MARK: - Toggle Current

    func toggle() {

        if isResolving {
            return
        }


        guard
            hasActiveTransport
        else {

            if let currentItem {

                resolveAndStart(
                    currentItem
                )
            }

            return
        }


        if isPlaying {

            pause()

            return
        }


        if duration > 0,
           currentTime
            >= duration - 0.25 {

            seek(
                toProgress:
                    0
            )
        }


        resumeActiveTransport()

        isPlaying =
            true
    }


    // MARK: - Toggle Local

    func toggle(
        track:
            LocalTrack,
        queue:
            [LocalTrack]
    ) {

        let item =
            PlaybackItem(
                local:
                    track
            )


        if currentItem?
            .id
            == item.id {

            playbackQueue
                .start(
                    item,
                    context:
                        queue.map {

                            PlaybackItem(
                                local:
                                    $0
                            )
                        }
                )

            toggle()

            return
        }


        play(
            track,
            queue:
                queue
        )
    }


    func toggle(
        track:
            LocalTrack
    ) {

        let effectiveQueue =
            queue.isEmpty
            ? [
                track
            ]
            : queue


        toggle(
            track:
                track,
            queue:
                effectiveQueue
        )
    }


    // MARK: - Toggle Openverse

    func toggle(
        openverse track:
            OpenverseAudio,
        queue:
            [OpenverseAudio]
    ) {

        let item =
            PlaybackItem(
                openverse:
                    track
            )


        if currentItem?
            .id
            == item.id {

            playbackQueue
                .start(
                    item,
                    context:
                        queue.map {

                            PlaybackItem(
                                openverse:
                                    $0
                            )
                        }
                )

            toggle()

            return
        }


        play(
            openverse:
                track,
            queue:
                queue
        )
    }


    func toggle(
        openverse track:
            OpenverseAudio
    ) {

        let effectiveQueue =
            openverseQueue.isEmpty
            ? [
                track
            ]
            : openverseQueue


        toggle(
            openverse:
                track,
            queue:
                effectiveQueue
        )
    }


    // MARK: - Queue Actions

    func playNext(
        _ item:
            PlaybackItem
    ) {

        playbackQueue
            .playNext(
                item
            )
    }


    func addToQueue(
        _ item:
            PlaybackItem
    ) {

        playbackQueue
            .addToQueue(
                item
            )
    }


    // MARK: - Local Queue Actions

    func playNext(
        _ track:
            LocalTrack
    ) {

        playNext(
            PlaybackItem(
                local:
                    track
            )
        )
    }


    func addToQueue(
        _ track:
            LocalTrack
    ) {

        addToQueue(
            PlaybackItem(
                local:
                    track
            )
        )
    }


    // MARK: - Openverse Queue Actions

    func playNext(
        openverse track:
            OpenverseAudio
    ) {

        playNext(
            PlaybackItem(
                openverse:
                    track
            )
        )
    }


    func addToQueue(
        openverse track:
            OpenverseAudio
    ) {

        addToQueue(
            PlaybackItem(
                openverse:
                    track
            )
        )
    }


    // MARK: - Remove / Move Queue

    func removeUpcoming(
        id:
            UUID
    ) {

        playbackQueue
            .removeUpcoming(
                id:
                    id
            )
    }


    func removeUpcoming(
        at offsets:
            IndexSet
    ) {

        playbackQueue
            .removeUpcoming(
                at:
                    offsets
            )
    }


    func moveUpcoming(
        fromOffsets:
            IndexSet,
        toOffset:
            Int
    ) {

        playbackQueue
            .moveUpcoming(
                fromOffsets:
                    fromOffsets,
                toOffset:
                    toOffset
            )
    }


    func clearUpcoming() {

        playbackQueue
            .clearUpcoming()
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


        guard
            let previous =
                playbackQueue
                    .movePrevious()
        else {

            restart()

            return
        }


        resolveAndStart(
            previous.item
        )
    }


    // MARK: - Next

    func next() {

        guard
            let next =
                playbackQueue
                    .advanceNext()
        else {

            return
        }


        resolveAndStart(
            next.item
        )
    }


    // MARK: - Pause

    func pause() {

        player?
            .pause()

        pcmEngine?
            .pause()

        isPlaying =
            false
    }


    // MARK: - Seek

    func seek(
        toProgress progress:
            Double
    ) {

        guard
            duration > 0
        else {

            return
        }


        let clamped =
            min(
                max(
                    progress,
                    0
                ),
                1
            )


        seek(
            to:
                duration
                * clamped
        )
    }


    func seek(
        to seconds:
            TimeInterval
    ) {

        guard
            hasActiveTransport
        else {

            return
        }


        let upperBound =
            duration > 0
            ? duration
            : seconds


        let clamped =
            min(
                max(
                    seconds,
                    0
                ),
                max(
                    0,
                    upperBound
                )
            )


        currentTime =
            clamped


        // AVPlayer transport
        if let player {

            let time =
                CMTime(
                    seconds:
                        clamped,
                    preferredTimescale:
                        600
                )


            player.seek(
                to:
                    time,
                toleranceBefore:
                    .zero,
                toleranceAfter:
                    .zero
            )

            return
        }


        // Extended PCM transport
        if let pcmEngine {

            Task {
                [weak self] in

                guard
                    let self,
                    self.pcmEngine === pcmEngine
                else {

                    return
                }

                do {

                    try await pcmEngine
                        .seek(
                            to:
                                clamped
                        )

                } catch {

                    guard
                        self.pcmEngine === pcmEngine
                    else {

                        return
                    }

                    self.playbackErrorMessage =
                        error.localizedDescription

                    self.isPlaying =
                        false

                    print(
                        "PCM Seek ✕",
                        error.localizedDescription
                    )
                }
            }
        }
    }


    // MARK: - Restart

    func restart() {

        guard
            hasActiveTransport
        else {

            return
        }


        seek(
            to:
                0
        )
    }


    // MARK: - Stop

    func stop() {

        cancelActiveResolution()


        player?
            .pause()


        if let player {

            player.seek(
                to:
                    .zero
            )
        }


        pcmEngine?
            .pause()


        if let pcmEngine {

            Task {
                [weak self] in

                guard
                    let self,
                    self.pcmEngine === pcmEngine
                else {

                    return
                }

                do {

                    try await pcmEngine
                        .seek(
                            to:
                                0
                        )

                } catch {

                    print(
                        "PCM Stop Seek △",
                        error.localizedDescription
                    )
                }
            }
        }


        currentTime =
            0

        isPlaying =
            false
    }


    // MARK: - Retry

    func retryLastFailedResolution() {

        guard
            let failedItem
        else {

            return
        }


        resolveAndStart(
            failedItem
        )
    }


    // MARK: - Resolve

    private func resolveAndStart(
        _ item:
            PlaybackItem
    ) {

        cancelActiveResolution()

        tearDownActiveTransport()


        currentResource =
            nil

        currentProviderID =
            nil

        currentTime =
            0

        duration =
            item.duration
            ?? 0

        isPlaying =
            false

        isResolving =
            true

        resolvingItem =
            item

        failedItem =
            nil

        playbackErrorMessage =
            nil


        let resolutionID =
            UUID()


        activeResolutionID =
            resolutionID


        let request =
            item.playbackRequest


        resolutionTask =
            Task {
                [weak self] in

                guard
                    let self
                else {

                    return
                }

                do {

                    let resource =
                        try await self
                            .providerKernel
                            .resolver
                            .resolve(
                                request
                            )


                    try Task
                        .checkCancellation()


                    guard
                        self.activeResolutionID
                            == resolutionID
                    else {

                        /*
                         如果这个 Resource 已经建立了
                         PCM Decode Session，而请求已经过期，
                         生命周期最终会随 Resource 释放。
                         */
                        return
                    }


                    try self
                        .activate(
                            resource:
                                resource,
                            item:
                                item
                        )


                    self.isResolving =
                        false

                    self.resolvingItem =
                        nil

                    self.failedItem =
                        nil

                    self.activeResolutionID =
                        nil

                    self.resolutionTask =
                        nil

                } catch is CancellationError {

                    guard
                        self.activeResolutionID
                            == resolutionID
                    else {

                        return
                    }


                    self.isResolving =
                        false

                    self.resolvingItem =
                        nil

                    self.activeResolutionID =
                        nil

                    self.resolutionTask =
                        nil

                } catch {

                    guard
                        self.activeResolutionID
                            == resolutionID
                    else {

                        return
                    }


                    self.isResolving =
                        false

                    self.resolvingItem =
                        nil

                    self.failedItem =
                        item

                    self.activeResolutionID =
                        nil

                    self.resolutionTask =
                        nil

                    self.playbackErrorMessage =
                        error
                            .localizedDescription


                    print(
                        "Playback Resolve ✕",
                        error.localizedDescription
                    )
                }
            }
    }


    // MARK: - Activate

    private func activate(
        resource:
            PlaybackResource,
        item:
            PlaybackItem
    ) throws {

        /*
         无论上一个 Transport 是 AVPlayer
         还是 PCM，都只通过这一处退出。
         */

        tearDownActiveTransport()


        switch resource.transport {

        // MARK: Apple-native AVPlayer

        case .avPlayerURL(
            let resolvedURL
        ):

            let newPlayer =
                AVPlayer(
                    url:
                        resolvedURL
                )


            player =
                newPlayer

            currentResource =
                resource

            currentProviderID =
                resource.providerID

            currentTime =
                0

            duration =
                resource.duration
                ?? item.duration
                ?? 0


            installObservers(
                for:
                    newPlayer
            )


            newPlayer
                .play()


            isPlaying =
                true


        // MARK: Extended Codec → PCM → AVAudioEngine

        case .decodedPCM(
            let pcmResource
        ):

            let engine =
                try PCMPlaybackEngine(
                    resource:
                        pcmResource
                )


            engine.onEnded = {
                [weak self] in

                self?
                    .handlePlaybackEnded()
            }


            engine.onFailure = {
                [weak self]
                error in

                guard
                    let self
                else {

                    return
                }


                self.playbackErrorMessage =
                    error.localizedDescription

                self.isPlaying =
                    false


                print(
                    "PCM Playback ✕",
                    error.localizedDescription
                )
            }


            pcmEngine =
                engine

            currentResource =
                resource

            currentProviderID =
                resource.providerID

            currentTime =
                0

            duration =
                resource.duration
                ?? pcmResource
                    .format
                    .duration
                ?? item.duration
                ?? 0


            startPCMTimeUpdates(
                engine
            )


            engine.play()


            isPlaying =
                true


        // MARK: Future Provider-native Transport

        case .providerNative(
            let providerID,
            _
        ):

            throw PlaybackControllerError
                .nativeTransportNotSupported(
                    providerID:
                        providerID
                )
        }


        print(
            "Playback ▶︎",
            "[\(resource.providerID.rawValue)]",
            item.title
        )
    }


    // MARK: - Active Transport

    private var hasActiveTransport:
        Bool {

        player != nil
        ||
        pcmEngine != nil
    }


    private func resumeActiveTransport() {

        player?
            .play()

        pcmEngine?
            .play()
    }


    private func tearDownActiveTransport() {

        /*
         先移除 AVPlayer Observer，
         此时 player 仍然存在。
         */

        removeObservers()


        player?
            .pause()

        player =
            nil


        /*
         PCM 时间观察任务只属于当前 Engine。
         */

        pcmTimeTask?
            .cancel()

        pcmTimeTask =
            nil


        /*
         先从 Controller 移除引用，
         再异步关闭旧 Engine。

         这样旧 Engine 的异步关闭不会误伤
         后续刚建立的新 Engine。
         */

        let previousPCMEngine =
            pcmEngine

        pcmEngine =
            nil


        if let previousPCMEngine {

            Task {

                await previousPCMEngine
                    .close()
            }
        }
    }


    // MARK: - PCM Time Updates

    private func startPCMTimeUpdates(
        _ engine:
            PCMPlaybackEngine
    ) {

        pcmTimeTask?
            .cancel()


        pcmTimeTask =
            Task {
                [weak self] in

                while
                    !Task.isCancelled {

                    do {

                        try await Task.sleep(
                            nanoseconds:
                                250_000_000
                        )

                    } catch {

                        return
                    }


                    guard
                        let self,
                        self.pcmEngine === engine
                    else {

                        return
                    }


                    self.currentTime =
                        engine.currentTime


                    if engine.duration > 0 {

                        self.duration =
                            engine.duration
                    }
                }
            }
    }


    // MARK: - Resolution Cancellation

    private func cancelActiveResolution() {

        resolutionTask?
            .cancel()

        resolutionTask =
            nil

        activeResolutionID =
            nil

        resolvingItem =
            nil

        isResolving =
            false
    }


    // MARK: - AVPlayer Observers

    private func installObservers(
        for player:
            AVPlayer
    ) {

        let interval =
            CMTime(
                seconds:
                    0.25,
                preferredTimescale:
                    600
            )


        timeObserver =
            player
                .addPeriodicTimeObserver(
                    forInterval:
                        interval,
                    queue:
                        .main
                ) {
                    [weak self, weak player]
                    time in


                    let seconds =
                        CMTimeGetSeconds(
                            time
                        )


                    guard
                        seconds.isFinite
                    else {

                        return
                    }


                    var resolvedDuration:
                        TimeInterval?


                    if let item =
                        player?
                            .currentItem {

                        let value =
                            CMTimeGetSeconds(
                                item.duration
                            )


                        if value.isFinite,
                           value > 0 {

                            resolvedDuration =
                                value
                        }
                    }


                    Task {
                        @MainActor
                        [weak self] in

                        guard
                            let self
                        else {

                            return
                        }


                        self.currentTime =
                            seconds


                        if let resolvedDuration {

                            self.duration =
                                resolvedDuration
                        }
                    }
                }


        if let item =
            player.currentItem {

            endObserver =
                NotificationCenter
                    .default
                    .addObserver(
                        forName:
                            .AVPlayerItemDidPlayToEndTime,
                        object:
                            item,
                        queue:
                            .main
                    ) {
                        [weak self]
                        _ in


                        Task {
                            @MainActor
                            [weak self] in

                            self?
                                .handlePlaybackEnded()
                        }
                    }
        }
    }


    private func removeObservers() {

        if let timeObserver,
           let player {

            player
                .removeTimeObserver(
                    timeObserver
                )
        }


        timeObserver =
            nil


        if let endObserver {

            NotificationCenter
                .default
                .removeObserver(
                    endObserver
                )
        }


        endObserver =
            nil
    }


    // MARK: - Playback End

    private func handlePlaybackEnded() {

        if playbackQueue
            .canNext {

            next()

            return
        }


        isPlaying =
            false

        currentTime =
            duration
    }
}


// MARK: - Errors

private enum PlaybackControllerError:
    LocalizedError {

    case nativeTransportNotSupported(
        providerID:
            PlaybackProviderID
    )


    var errorDescription:
        String? {

        switch self {

        case .nativeTransportNotSupported(
            let providerID
        ):

            return
                "Native playback transport for \(providerID.rawValue) is not implemented yet."
        }
    }
}
