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


    // MARK: - Current Playback

    private(set) var currentTrack:
        LocalTrack?

    private(set) var currentResource:
        PlaybackResource?

    private(set) var currentProviderID:
        PlaybackProviderID?


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


    // MARK: - Queue

    private(set) var queue:
        [LocalTrack] = []

    private(set) var currentIndex:
        Int?


    // MARK: - Player

    private var player:
        AVPlayer?

    private var timeObserver:
        Any?

    private var endObserver:
        NSObjectProtocol?


    // MARK: - Resolution

    private var resolutionTask:
        Task<Void, Never>?

    private var activeResolutionID:
        UUID?


    // MARK: - Init

    init(
        providerKernel:
            PlaybackProviderKernel = .standard()
    ) {

        self.providerKernel =
            providerKernel
    }


    // MARK: - Queue State

    var canGoPrevious:
        Bool {

        guard
            let currentIndex
        else {
            return false
        }


        return currentIndex > 0
    }


    var canGoNext:
        Bool {

        guard
            let currentIndex
        else {
            return false
        }


        return currentIndex
            < queue.count - 1
    }


    var upNextTracks:
        [LocalTrack] {

        guard
            let currentIndex
        else {
            return []
        }


        let nextIndex =
            currentIndex + 1


        guard
            nextIndex
            < queue.count
        else {
            return []
        }


        return Array(
            queue[
                nextIndex...
            ]
        )
    }


    // MARK: - Progress

    var progress:
        Double {

        guard duration > 0 else {
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


    // MARK: - Play

    func play(
        _ track:
            LocalTrack,
        queue newQueue:
            [LocalTrack]? = nil
    ) {

        let targetIndex =
            prepareQueue(
                for:
                    track,
                newQueue:
                    newQueue
            )


        /*
         已经是当前歌曲。

         不需要重新 Resolve。
         */

        if currentTrack?.id
            == track.id {

            currentIndex =
                targetIndex


            if duration > 0,
               currentTime
                >= duration - 0.25 {

                seek(
                    toProgress: 0
                )
            }


            player?.play()

            isPlaying =
                true


            return
        }


        resolveAndStart(
            track,
            targetIndex:
                targetIndex
        )
    }


    // MARK: - Toggle Current

    func toggle() {

        guard
            let player
        else {
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
                toProgress: 0
            )
        }


        player.play()

        isPlaying =
            true
    }


    // MARK: - Toggle Track

    func toggle(
        track:
            LocalTrack,
        queue newQueue:
            [LocalTrack]
    ) {

        let targetIndex =
            prepareQueue(
                for:
                    track,
                newQueue:
                    newQueue
            )


        if currentTrack?.id
            == track.id {

            currentIndex =
                targetIndex

            toggle()

        } else {

            resolveAndStart(
                track,
                targetIndex:
                    targetIndex
            )
        }
    }


    /*
     保留旧接口兼容性。

     如果其他页面暂时仍然调用：
     toggle(track:)
     不会直接编译炸掉。
     */

    func toggle(
        track:
            LocalTrack
    ) {

        let effectiveQueue =
            queue.isEmpty
            ? [track]
            : queue


        toggle(
            track:
                track,
            queue:
                effectiveQueue
        )
    }


    // MARK: - Pause

    func pause() {

        player?.pause()

        isPlaying =
            false
    }


    // MARK: - Previous

    func previous() {

        guard
            let currentIndex,
            currentIndex > 0
        else {
            return
        }


        let targetIndex =
            currentIndex - 1


        let track =
            queue[
                targetIndex
            ]


        resolveAndStart(
            track,
            targetIndex:
                targetIndex
        )
    }


    // MARK: - Next

    func next() {

        guard
            let currentIndex,
            currentIndex
                < queue.count - 1
        else {
            return
        }


        let targetIndex =
            currentIndex + 1


        let track =
            queue[
                targetIndex
            ]


        resolveAndStart(
            track,
            targetIndex:
                targetIndex
        )
    }


    // MARK: - Seek

    func seek(
        toProgress progress:
            Double
    ) {

        guard duration > 0 else {
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


        let seconds =
            duration
            * clamped


        currentTime =
            seconds


        let time =
            CMTime(
                seconds:
                    seconds,
                preferredTimescale:
                    600
            )


        player?.seek(
            to:
                time,
            toleranceBefore:
                .zero,
            toleranceAfter:
                .zero
        )
    }


    // MARK: - Restart

    func restart() {

        guard player != nil else {
            return
        }


        currentTime =
            0


        player?.seek(
            to:
                .zero
        )


        if isPlaying {

            player?.play()
        }
    }


    // MARK: - Clear Upcoming

    func clearUpcoming() {

        guard
            let currentTrack
        else {

            queue =
                []

            currentIndex =
                nil

            return
        }


        queue =
            [
                currentTrack
            ]


        currentIndex =
            0
    }


    // MARK: - Stop

    func stop() {

        cancelActiveResolution()


        player?.pause()

        player?.seek(
            to:
                .zero
        )


        currentTime =
            0

        isPlaying =
            false
    }


    // MARK: - Queue Preparation

    private func prepareQueue(
        for track:
            LocalTrack,
        newQueue:
            [LocalTrack]?
    ) -> Int {

        /*
         外部给了新的 Queue：

         例如 LocalLibraryView
         把 store.tracks 整体交进来。
         */

        if let newQueue {

            queue =
                newQueue
        }


        /*
         当前 Queue 里找到这首。
         */

        if let index =
            queue.firstIndex(
                where: {
                    $0.id
                        == track.id
                }
            ) {

            return index
        }


        /*
         Queue 中不存在这首：

         将当前 Queue 收敛成单曲。
         */

        queue =
            [
                track
            ]


        return 0
    }


    // MARK: - Resolve

    private func resolveAndStart(
        _ track:
            LocalTrack,
        targetIndex:
            Int
    ) {

        resolutionTask?
            .cancel()


        let resolutionID =
            UUID()


        activeResolutionID =
            resolutionID

        isResolving =
            true

        playbackErrorMessage =
            nil


        let request =
            PlaybackRequest(
                trackID:
                    track.id,
                preferredQuality:
                    .automatic,
                localFileURL:
                    track.fileURL
            )


        resolutionTask =
            Task {
                [weak self] in

                guard let self else {
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


                    guard
                        !Task.isCancelled,
                        self.activeResolutionID
                            == resolutionID
                    else {
                        return
                    }


                    try self
                        .activate(
                            resource:
                                resource,
                            track:
                                track,
                            targetIndex:
                                targetIndex
                        )


                    self.isResolving =
                        false

                    self.activeResolutionID =
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

                    self.activeResolutionID =
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

                    self.activeResolutionID =
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


    // MARK: - Activate Resource

    private func activate(
        resource:
            PlaybackResource,
        track:
            LocalTrack,
        targetIndex:
            Int
    ) throws {

        let url:
            URL


        switch resource.transport {

        case .avPlayerURL(
            let resolvedURL
        ):

            url =
                resolvedURL


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


        // MARK: Replace Player

        removeObservers()


        let newPlayer =
            AVPlayer(
                url:
                    url
            )


        player =
            newPlayer


        // MARK: Commit State

        currentTrack =
            track

        currentIndex =
            targetIndex

        currentResource =
            resource

        currentProviderID =
            resource.providerID


        currentTime =
            0

        duration =
            track.duration


        // MARK: Observe

        installObservers(
            for:
                newPlayer
        )


        // MARK: Start

        newPlayer.play()

        isPlaying =
            true


        print(
            "Playback ▶︎",
            "[\(resource.providerID.rawValue)]",
            track.title
        )
    }


    // MARK: - Resolution Cancellation

    private func cancelActiveResolution() {

        resolutionTask?
            .cancel()


        resolutionTask =
            nil

        activeResolutionID =
            nil

        isResolving =
            false
    }


    // MARK: - Observers

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
                    [weak self] time in

                    let seconds =
                        CMTimeGetSeconds(
                            time
                        )


                    guard
                        seconds.isFinite
                    else {
                        return
                    }


                    Task {
                        @MainActor
                        [weak self] in

                        self?
                            .currentTime =
                            seconds
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
                        [weak self] _ in

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


    // MARK: - End

    private func handlePlaybackEnded() {

        if canGoNext {

            next()

        } else {

            isPlaying =
                false

            currentTime =
                duration
        }
    }
}


// MARK: - Controller Errors

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
