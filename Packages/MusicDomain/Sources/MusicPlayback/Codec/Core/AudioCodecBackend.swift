//
//  AudioCodecBackend.swift
//  MSRU
//

import Foundation


public nonisolated struct PCMStreamFormat: Sendable {

    public let sampleRate: Double

    public let channels: UInt32

    public let channelLayoutMask: UInt64

    public let duration: TimeInterval?

    public let bitRate: Int64

    public let canSeek: Bool

    public let formatHint: String


    public nonisolated init(
        sampleRate: Double,
        channels: UInt32,
        channelLayoutMask: UInt64 = 0,
        duration: TimeInterval? = nil,
        bitRate: Int64 = 0,
        canSeek: Bool = true,
        formatHint: String = ""
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.channelLayoutMask = channelLayoutMask
        self.duration = duration
        self.bitRate = bitRate
        self.canSeek = canSeek
        self.formatHint = formatHint
    }
}


public nonisolated struct PCMFrameBlock: Sendable {

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


    public nonisolated init(
        channels: [[Float]],
        frameCount: Int
    ) {
        self.channels = channels
        self.frameCount = frameCount
    }

    public nonisolated init(
        left: [Float],
        right: [Float],
        frameCount: Int
    ) {
        self.channels = [left, right]
        self.frameCount = frameCount
    }
}


public protocol PCMDecodeSession: Sendable {

    func read(
        maxFrames: Int
    ) async throws -> PCMFrameBlock?


    func seek(
        to seconds: TimeInterval
    ) async throws


    func close() async
}


public struct AudioCodecOpenResult: Sendable {

    public let format: PCMStreamFormat

    public let session: any PCMDecodeSession

    public init(format: PCMStreamFormat, session: any PCMDecodeSession) {
        self.format = format
        self.session = session
    }
}


public protocol AudioCodecBackend: Sendable {

    var id: String { get }


    func canDecode(
        _ url: URL
    ) -> Bool


    func open(
        _ url: URL
    ) async throws -> AudioCodecOpenResult
}


// MARK: - Extended Formats

public nonisolated enum ExtendedAudioFormatSupport {

    public static let extensions: Set<String> = [
        "dts",
        "dtshd",
        "ape",
        "dsf",
        "dff"
    ]


    public static func supports(
        _ url: URL
    ) -> Bool {
        extensions.contains(
            url.pathExtension.lowercased()
        )
    }
}

// MARK: - FFmpeg Codec Backend

import MSRUCodecFFmpeg
import MusicDomain
import MusicLibrary

public struct FFmpegCodecBackend: AudioCodecBackend {

    public let id = "ffmpeg"

    public func canDecode(_ url: URL) -> Bool {
        ExtendedAudioFormatSupport.supports(url)
    }

    public func open(_ url: URL) async throws -> AudioCodecOpenResult {
        let decoder = try FFmpegAudioDecoder(url: url)

        let format = PCMStreamFormat(
            sampleRate: decoder.format.sampleRate,
            channels: UInt32(decoder.format.channels),
            channelLayoutMask: decoder.format.channelLayoutMask,
            duration: decoder.format.duration,
            bitRate: decoder.format.bitRate,
            canSeek: decoder.format.canSeek,
            formatHint: "\(decoder.format.codecName.uppercased()) (\(decoder.format.formatName))"
        )

        let session = FFmpegPCMDecodeSession(decoder: decoder)

        return AudioCodecOpenResult(
            format: format,
            session: session
        )
    }

    nonisolated public init() {}
}

private actor FFmpegPCMDecodeSession: PCMDecodeSession {

    private let decoder: FFmpegAudioDecoder

    public init(decoder: FFmpegAudioDecoder) {
        self.decoder = decoder
    }

    public func read(maxFrames: Int) async throws -> PCMFrameBlock? {
        guard let block = try decoder.read(maxFrames: maxFrames) else {
            return nil
        }
        return PCMFrameBlock(
            channels: block.channels,
            frameCount: block.frameCount
        )
    }

    public func seek(to seconds: TimeInterval) async throws {
        try decoder.seek(to: seconds)
    }

    public func close() async {
        decoder.close()
    }
}

