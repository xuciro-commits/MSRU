//
//  FFmpegAudioDecoder.swift
//  MSRUCodecFFmpeg
//

import Foundation
import CFFmpegBridge


public struct FFmpegAudioFormat: Sendable {

    public let sampleRate: Double

    public let channels: Int

    public let channelLayoutMask: UInt64

    public let duration: TimeInterval?

    public let bitRate: Int64

    public let canSeek: Bool

    public let codecName: String

    public let formatName: String


    public init(
        sampleRate: Double,
        channels: Int,
        channelLayoutMask: UInt64 = 0,
        duration: TimeInterval?,
        bitRate: Int64,
        canSeek: Bool = true,
        codecName: String = "",
        formatName: String = ""
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.channelLayoutMask = channelLayoutMask
        self.duration = duration
        self.bitRate = bitRate
        self.canSeek = canSeek
        self.codecName = codecName
        self.formatName = formatName
    }
}


public struct FFmpegPCMBlock: Sendable {

    public let channels: [[Float]]

    public let frameCount: Int

    public var channelCount: Int {
        channels.count
    }

    public var left: [Float] {
        channels.isEmpty ? [] : channels[0]
    }

    public var right: [Float] {
        channels.count > 1 ? channels[1] : (channels.first ?? [])
    }

    public init(
        channels: [[Float]],
        frameCount: Int
    ) {
        self.channels = channels
        self.frameCount = frameCount
    }
}


public enum FFmpegAudioDecoderError: LocalizedError, Sendable {

    case openFailed(String)
    case decodeFailed(String)
    case seekFailed(String)
    case closed

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return message
        case .decodeFailed(let message):
            return message
        case .seekFailed(let message):
            return message
        case .closed:
            return "FFmpeg audio decoder is closed."
        }
    }
}


public final class FFmpegAudioDecoder: @unchecked Sendable {

    private let lock = NSLock()
    private var handle: MSRUFFmpegDecoderRef?

    public let format: FFmpegAudioFormat

    public static var ffmpegVersion: String {
        guard let pointer = msru_ffmpeg_version() else {
            return "Unknown"
        }
        return String(cString: pointer)
    }

    // MARK: - Init

    public init(url: URL) throws {
        var info = MSRUFFmpegAudioInfo()
        var errorBuffer = [CChar](repeating: 0, count: 1024)
        let path = url.path

        let decoder: MSRUFFmpegDecoderRef? = errorBuffer.withUnsafeMutableBufferPointer { errorPointer in
            path.withCString { pathPointer in
                msru_ffmpeg_decoder_open(
                    pathPointer,
                    &info,
                    errorPointer.baseAddress,
                    Int32(errorPointer.count)
                )
            }
        }

        guard let decoder else {
            throw FFmpegAudioDecoderError.openFailed(Self.message(from: errorBuffer))
        }

        self.handle = decoder

        var codecStr = "unknown"
        withUnsafePointer(to: &info.codec_name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 32) { cStr in
                codecStr = String(cString: cStr)
            }
        }

        var formatStr = "unknown"
        withUnsafePointer(to: &info.format_name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 32) { cStr in
                formatStr = String(cString: cStr)
            }
        }

        self.format = FFmpegAudioFormat(
            sampleRate: Double(info.sample_rate),
            channels: Int(info.channels),
            channelLayoutMask: info.channel_layout_mask,
            duration: info.duration_seconds > 0 ? info.duration_seconds : nil,
            bitRate: info.bit_rate,
            canSeek: info.can_seek != 0,
            codecName: codecStr,
            formatName: formatStr
        )
    }

    deinit {
        close()
    }

    // MARK: - Read

    public func read(
        maxFrames: Int = 8192
    ) throws -> FFmpegPCMBlock? {
        guard maxFrames > 0 else { return nil }

        lock.lock()
        defer { lock.unlock() }

        guard let handle else {
            throw FFmpegAudioDecoderError.closed
        }

        let channelCount = max(1, format.channels)

        // Safely allocate dedicated native float buffers for each channel
        var channelPointers = [UnsafeMutablePointer<Float>?]()
        channelPointers.reserveCapacity(channelCount)
        for _ in 0..<channelCount {
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: maxFrames)
            ptr.initialize(repeating: 0, count: maxFrames)
            channelPointers.append(ptr)
        }
        defer {
            for ptr in channelPointers {
                ptr?.deallocate()
            }
        }

        var outputFrames: Int32 = 0
        var errorBuffer = [CChar](repeating: 0, count: 1024)

        let result = channelPointers.withUnsafeMutableBufferPointer { ptrList in
            errorBuffer.withUnsafeMutableBufferPointer { errorPointer in
                msru_ffmpeg_decoder_read(
                    handle,
                    ptrList.baseAddress,
                    Int32(channelCount),
                    Int32(maxFrames),
                    &outputFrames,
                    errorPointer.baseAddress,
                    Int32(errorPointer.count)
                )
            }
        }

        if result < 0 {
            throw FFmpegAudioDecoderError.decodeFailed(Self.message(from: errorBuffer))
        }

        guard result > 0, outputFrames > 0 else {
            return nil
        }

        let count = Int(outputFrames)
        let channels: [[Float]] = (0..<channelCount).map { ch in
            if let ptr = channelPointers[ch] {
                return Array(UnsafeBufferPointer(start: ptr, count: count))
            } else {
                return [Float](repeating: 0, count: count)
            }
        }

        return FFmpegPCMBlock(
            channels: channels,
            frameCount: count
        )
    }

    // MARK: - Seek

    public func seek(
        to seconds: TimeInterval
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let handle else {
            throw FFmpegAudioDecoderError.closed
        }

        var errorBuffer = [CChar](repeating: 0, count: 1024)
        let result = errorBuffer.withUnsafeMutableBufferPointer { errorPointer in
            msru_ffmpeg_decoder_seek(
                handle,
                seconds,
                errorPointer.baseAddress,
                Int32(errorPointer.count)
            )
        }

        guard result >= 0 else {
            throw FFmpegAudioDecoderError.seekFailed(Self.message(from: errorBuffer))
        }
    }

    // MARK: - Close

    public func close() {
        lock.lock()
        defer { lock.unlock() }

        guard let handle else { return }
        msru_ffmpeg_decoder_close(handle)
        self.handle = nil
    }

    // MARK: - Message

    private static func message(from buffer: [CChar]) -> String {
        guard buffer.first != 0 else {
            return "Unknown FFmpeg decoder error."
        }
        return buffer.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }
}
