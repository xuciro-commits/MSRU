//
//  FFmpegAudioDecoder.swift
//  MSRUCodecFFmpeg
//

import Foundation
import CFFmpegBridge


public struct FFmpegAudioFormat:
    Sendable {

    public let sampleRate:
        Double

    public let channels:
        Int

    public let duration:
        TimeInterval?

    public let bitRate:
        Int64


    public init(
        sampleRate:
            Double,
        channels:
            Int,
        duration:
            TimeInterval?,
        bitRate:
            Int64
    ) {

        self.sampleRate =
            sampleRate

        self.channels =
            channels

        self.duration =
            duration

        self.bitRate =
            bitRate
    }
}


public struct FFmpegPCMBlock:
    Sendable {

    public let left:
        [Float]

    public let right:
        [Float]

    public let frameCount:
        Int
}


public enum FFmpegAudioDecoderError:
    LocalizedError,
    Sendable {

    case openFailed(
        String
    )

    case decodeFailed(
        String
    )

    case seekFailed(
        String
    )

    case closed


    public var errorDescription:
        String? {

        switch self {

        case .openFailed(
            let message
        ):

            return message


        case .decodeFailed(
            let message
        ):

            return message


        case .seekFailed(
            let message
        ):

            return message


        case .closed:

            return
                "FFmpeg audio decoder is closed."
        }
    }
}


public final class FFmpegAudioDecoder:
    @unchecked Sendable {

    private let lock =
        NSLock()


    private var handle:
        MSRUFFmpegDecoderRef?


    public let format:
        FFmpegAudioFormat


    public static var ffmpegVersion:
        String {

        guard
            let pointer =
                msru_ffmpeg_version()
        else {

            return "Unknown"
        }


        return String(
            cString:
                pointer
        )
    }


    // MARK: - Init

    public init(
        url:
            URL
    ) throws {

        var info =
            MSRUFFmpegAudioInfo()


        var errorBuffer =
            [CChar](
                repeating:
                    0,
                count:
                    1024
            )


        let path =
            url.path


        let decoder:

            MSRUFFmpegDecoderRef? =
                errorBuffer
                    .withUnsafeMutableBufferPointer {
                        errorPointer in

                        path
                            .withCString {
                                pathPointer in

                                msru_ffmpeg_decoder_open(
                                    pathPointer,
                                    &info,
                                    errorPointer.baseAddress,
                                    Int32(
                                        errorPointer.count
                                    )
                                )
                            }
                    }


        guard
            let decoder
        else {

            throw FFmpegAudioDecoderError
                .openFailed(
                    Self.message(
                        from:
                            errorBuffer
                    )
                )
        }


        self.handle =
            decoder


        self.format =
            FFmpegAudioFormat(

                sampleRate:
                    Double(
                        info.sample_rate
                    ),

                channels:
                    Int(
                        info.channels
                    ),

                duration:
                    info.duration_seconds
                    > 0
                    ? info.duration_seconds
                    : nil,

                bitRate:
                    info.bit_rate
            )


        print(
            """
            FFmpeg DTS ✓
            version: \(Self.ffmpegVersion)
            sampleRate: \(format.sampleRate)
            channels: \(format.channels)
            bitrate: \(format.bitRate)
            duration: \(format.duration ?? 0)
            """
        )
    }


    deinit {

        close()
    }


    // MARK: - Read

    public func read(
        maxFrames:
            Int = 8192
    ) throws -> FFmpegPCMBlock? {

        guard
            maxFrames > 0
        else {

            return nil
        }


        lock.lock()

        defer {
            lock.unlock()
        }


        guard
            let handle
        else {

            throw FFmpegAudioDecoderError
                .closed
        }


        var left =
            [Float](
                repeating:
                    0,
                count:
                    maxFrames
            )


        var right =
            [Float](
                repeating:
                    0,
                count:
                    maxFrames
            )


        var outputFrames:
            Int32 = 0


        var errorBuffer =
            [CChar](
                repeating:
                    0,
                count:
                    1024
            )


        let result =
            left.withUnsafeMutableBufferPointer {
                leftPointer in

                right.withUnsafeMutableBufferPointer {
                    rightPointer in

                    errorBuffer.withUnsafeMutableBufferPointer {
                        errorPointer in

                        msru_ffmpeg_decoder_read(

                            handle,

                            leftPointer
                                .baseAddress,

                            rightPointer
                                .baseAddress,

                            Int32(
                                maxFrames
                            ),

                            &outputFrames,

                            errorPointer
                                .baseAddress,

                            Int32(
                                errorPointer.count
                            )
                        )
                    }
                }
            }


        if result < 0 {

            throw FFmpegAudioDecoderError
                .decodeFailed(
                    Self.message(
                        from:
                            errorBuffer
                    )
                )
        }


        guard
            result > 0,
            outputFrames > 0
        else {

            return nil
        }


        let count =
            Int(
                outputFrames
            )


        if count < maxFrames {

            left.removeSubrange(
                count...
            )

            right.removeSubrange(
                count...
            )
        }


        return FFmpegPCMBlock(
            left:
                left,
            right:
                right,
            frameCount:
                count
        )
    }


    // MARK: - Seek

    public func seek(
        to seconds:
            TimeInterval
    ) throws {

        lock.lock()

        defer {
            lock.unlock()
        }


        guard
            let handle
        else {

            throw FFmpegAudioDecoderError
                .closed
        }


        var errorBuffer =
            [CChar](
                repeating:
                    0,
                count:
                    1024
            )


        let result =
            errorBuffer
                .withUnsafeMutableBufferPointer {
                    errorPointer in

                    msru_ffmpeg_decoder_seek(

                        handle,

                        seconds,

                        errorPointer
                            .baseAddress,

                        Int32(
                            errorPointer.count
                        )
                    )
                }


        guard
            result >= 0
        else {

            throw FFmpegAudioDecoderError
                .seekFailed(
                    Self.message(
                        from:
                            errorBuffer
                    )
                )
        }
    }


    // MARK: - Close

    public func close() {

        lock.lock()

        defer {
            lock.unlock()
        }


        guard
            let handle
        else {

            return
        }


        msru_ffmpeg_decoder_close(
            handle
        )


        self.handle =
            nil
    }


    // MARK: - Message

    private static func message(
        from buffer:
            [CChar]
    ) -> String {

        guard
            buffer.first != 0
        else {

            return
                "Unknown FFmpeg decoder error."
        }


        return buffer
            .withUnsafeBufferPointer {
                pointer in

                String(
                    cString:
                        pointer.baseAddress!
                )
            }
    }
}
