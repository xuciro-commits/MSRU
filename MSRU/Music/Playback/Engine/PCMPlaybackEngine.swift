//
//  PCMPlaybackEngine.swift
//  MSRU
//

import AVFoundation
import Foundation


@MainActor
final class PCMPlaybackEngine {

    typealias EndHandler =
        @MainActor () -> Void


    typealias FailureHandler =
        @MainActor (Error) -> Void


    var onEnded:
        EndHandler?


    var onFailure:
        FailureHandler?


    private let audioEngine =
        AVAudioEngine()


    private let playerNode =
        AVAudioPlayerNode()


    private let session:
        any PCMDecodeSession


    let format:
        PCMStreamFormat


    private let audioFormat:
        AVAudioFormat


    private var decodeTask:
        Task<Void, Never>?


    private var generation =
        0


    private var scheduledBufferCount =
        0


    private var decoderReachedEnd =
        false


    private var wantsToPlay =
        false


    private var baseTime:
        TimeInterval = 0


    private let maximumScheduledBuffers =
        4


    private let decodeBlockFrames =
        8192


    // MARK: - Init

    init(
        resource:
            PCMPlaybackResource
    ) throws {

        self.session =
            resource.session


        self.format =
            resource.format


        guard
            let audioFormat =
                AVAudioFormat(

                    commonFormat:
                        .pcmFormatFloat32,

                    sampleRate:
                        resource
                            .format
                            .sampleRate,

                    channels:
                        AVAudioChannelCount(
                            resource
                                .format
                                .channels
                        ),

                    interleaved:
                        false
                )
        else {

            throw PCMPlaybackEngineError
                .invalidAudioFormat
        }


        self.audioFormat =
            audioFormat


        audioEngine.attach(
            playerNode
        )


        try connectPlayerNode(
            to: audioEngine.mainMixerNode,
            format: audioFormat
        )


        audioEngine.prepare()


        try audioEngine
            .start()
    }


    // MARK: - State

    var isPlaying:
        Bool {

        wantsToPlay
        &&
        playerNode
            .isPlaying
    }


    var duration:
        TimeInterval {

        format.duration
        ?? 0
    }

    var volume: Float {
        get { playerNode.volume }
        set { playerNode.volume = newValue }
    }


    var currentTime:
        TimeInterval {

        guard
            let renderTime =
                playerNode
                    .lastRenderTime,

            let playerTime =
                playerNode
                    .playerTime(
                        forNodeTime:
                            renderTime
                    )
        else {

            return baseTime
        }


        let played =
            Double(
                playerTime
                    .sampleTime
            )
            /
            playerTime
                .sampleRate


        let value =
            baseTime
            + max(
                0,
                played
            )


        if duration > 0 {

            return min(
                value,
                duration
            )
        }


        return value
    }


    // MARK: - Play

    func play() {

        wantsToPlay =
            true


        if decodeTask == nil,
           !decoderReachedEnd {

            beginDecoding()
        }


        if scheduledBufferCount > 0,
           !playerNode.isPlaying {

            startPlayerNode()
        }
    }


    // MARK: - Pause

    func pause() {

        wantsToPlay =
            false


        playerNode.pause()
    }


    // MARK: - Seek

    func seek(
        to seconds:
            TimeInterval
    ) async throws {

        let clamped:

            TimeInterval


        if duration > 0 {

            clamped =
                min(
                    max(
                        seconds,
                        0
                    ),
                    duration
                )

        } else {

            clamped =
                max(
                    seconds,
                    0
                )
        }


        generation +=
            1


        decodeTask?
            .cancel()


        decodeTask =
            nil


        playerNode.stop()


        scheduledBufferCount =
            0


        decoderReachedEnd =
            false


        baseTime =
            clamped


        try await session
            .seek(
                to:
                    clamped
            )


        beginDecoding()
    }


    // MARK: - Close

    func close()
        async {

        generation +=
            1


        decodeTask?
            .cancel()


        decodeTask =
            nil


        wantsToPlay =
            false


        playerNode.stop()


        audioEngine.stop()


        await session
            .close()
    }


    // MARK: - Decode Loop

    private func beginDecoding() {

        generation +=
            1


        let activeGeneration =
            generation


        decoderReachedEnd =
            false


        decodeTask =
            Task {
                [weak self] in

                guard
                    let self
                else {

                    return
                }


                await decodeLoop(
                    generation:
                        activeGeneration
                )
            }
    }


    private func decodeLoop(
        generation:
            Int
    ) async {

        while
            !Task.isCancelled,
            generation == self.generation {

            /*
             Keep only a small amount of PCM
             queued in AVAudioPlayerNode.

             4 × 8192 frames at 48 kHz
             is ~680 ms of decoded PCM.
             */

            while
                scheduledBufferCount
                    >= maximumScheduledBuffers {

                do {

                    try await Task.sleep(
                        nanoseconds:
                            5_000_000
                    )

                } catch {

                    return
                }


                guard
                    generation
                        == self.generation
                else {

                    return
                }
            }


            do {

                guard
                    let block =
                        try await session
                            .read(
                                maxFrames:
                                    decodeBlockFrames
                            )
                else {

                    decoderReachedEnd =
                        true


                    decodeTask =
                        nil


                    if scheduledBufferCount
                        == 0 {

                        finishPlayback()
                    }


                    return
                }


                guard
                    !Task.isCancelled,
                    generation
                        == self.generation
                else {

                    return
                }


                try schedule(
                    block,
                    generation:
                        generation
                )

            } catch is CancellationError {

                return

            } catch {

                guard
                    generation
                        == self.generation
                else {

                    return
                }


                decodeTask =
                    nil


                wantsToPlay =
                    false


                playerNode.stop()


                onFailure?(
                    error
                )


                return
            }
        }
    }


    // MARK: - Schedule

    private func schedule(
        _ block:
            PCMFrameBlock,
        generation:
            Int
    ) throws {

        guard
            block.frameCount > 0
        else {

            return
        }


        guard
            block.left.count
                >= block.frameCount,
            block.right.count
                >= block.frameCount
        else {

            throw PCMPlaybackEngineError
                .invalidPCMBlock
        }


        guard
            let buffer =
                AVAudioPCMBuffer(

                    pcmFormat:
                        audioFormat,

                    frameCapacity:
                        AVAudioFrameCount(
                            block.frameCount
                        )
                ),

            let channels =
                buffer
                    .floatChannelData
        else {

            throw PCMPlaybackEngineError
                .bufferAllocationFailed
        }


        buffer.frameLength =
            AVAudioFrameCount(
                block.frameCount
            )


        block.left
            .withUnsafeBufferPointer {
                source in

                guard
                    let baseAddress =
                        source.baseAddress
                else {

                    return
                }


                memcpy(

                    channels[0],

                    baseAddress,

                    block.frameCount
                    *
                    MemoryLayout<Float>
                        .size
                )
            }


        block.right
            .withUnsafeBufferPointer {
                source in

                guard
                    let baseAddress =
                        source.baseAddress
                else {

                    return
                }


                memcpy(

                    channels[1],

                    baseAddress,

                    block.frameCount
                    *
                    MemoryLayout<Float>
                        .size
                )
            }


        scheduledBufferCount +=
            1


        playerNode.scheduleBuffer(

            buffer,

            completionCallbackType:
                .dataPlayedBack
        ) {
            [weak self]
            _ in

            Task {
                @MainActor
                [weak self] in

                self?
                    .bufferDidFinish(
                        generation:
                            generation
                    )
            }
        }


        if wantsToPlay,
           !playerNode.isPlaying {

            startPlayerNode()
        }
    }

    // MARK: - Safe Modern Audio Engine Helpers

    private func connectPlayerNode(to mixer: AVAudioNode, format: AVAudioFormat) throws {
        if #available(macOS 27.0, iOS 27.0, tvOS 27.0, watchOS 27.0, *) {
            try audioEngine.connectNode(playerNode, to: mixer, format: format)
        } else {
            audioEngine.connect(playerNode, to: mixer, format: format)
        }
    }

    private func startPlayerNode() {
        if #available(macOS 27.0, iOS 27.0, tvOS 27.0, watchOS 27.0, *) {
            try? playerNode.playAudio()
        } else {
            playerNode.play()
        }
    }


    // MARK: - Completion

    private func bufferDidFinish(
        generation:
            Int
    ) {

        guard
            generation
                == self.generation
        else {

            return
        }


        scheduledBufferCount =
            max(
                0,
                scheduledBufferCount
                - 1
            )


        if decoderReachedEnd,
           scheduledBufferCount == 0 {

            finishPlayback()
        }
    }


    private func finishPlayback() {

        wantsToPlay =
            false


        baseTime =
            duration > 0
            ? duration
            : currentTime


        onEnded?()
    }
}


private enum PCMPlaybackEngineError:
    LocalizedError {

    case invalidAudioFormat

    case invalidPCMBlock

    case bufferAllocationFailed


    var errorDescription:
        String? {

        switch self {

        case .invalidAudioFormat:

            return
                "Unable to create the PCM playback format."


        case .invalidPCMBlock:

            return
                "The decoder returned an invalid PCM block."


        case .bufferAllocationFailed:

            return
                "Unable to allocate an AVAudioPCMBuffer."
        }
    }
}
