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
        let ext = url.pathExtension.lowercased()
        if extensions.contains(ext) {
            return true
        }
        if ext == "wav" && isDTSWAV(url) {
            return true
        }
        return false
    }

    public static func isDTSWAV(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard let headerData = try? handle.read(upToCount: 2048), headerData.count >= 44 else {
            return false
        }

        return headerData.withUnsafeBytes { raw in
            guard let ptr = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            // Must start with RIFF .... WAVE
            guard ptr[0] == 0x52 && ptr[1] == 0x49 && ptr[2] == 0x46 && ptr[3] == 0x46,
                  ptr[8] == 0x57 && ptr[9] == 0x41 && ptr[10] == 0x56 && ptr[11] == 0x45 else {
                return false
            }

            var offset = 12
            let count = headerData.count
            while offset + 8 <= count {
                let c0 = ptr[offset]
                let c1 = ptr[offset + 1]
                let c2 = ptr[offset + 2]
                let c3 = ptr[offset + 3]
                let chunkSize = Int(UInt32(ptr[offset + 4]) | (UInt32(ptr[offset + 5]) << 8) | (UInt32(ptr[offset + 6]) << 16) | (UInt32(ptr[offset + 7]) << 24))
                offset += 8

                // fmt chunk: check format tag 0x2001 (WAVE_FORMAT_DTS)
                if c0 == 0x66 && c1 == 0x6d && c2 == 0x74 && c3 == 0x20 {
                    if offset + 2 <= count {
                        let formatTag = UInt16(ptr[offset]) | (UInt16(ptr[offset + 1]) << 8)
                        if formatTag == 0x2001 { return true }
                    }
                } else if c0 == 0x64 && c1 == 0x61 && c2 == 0x74 && c3 == 0x61 {
                    // data chunk: check first 4 bytes for DTS sync word
                    if offset + 4 <= count {
                        let b0 = ptr[offset]
                        let b1 = ptr[offset + 1]
                        let b2 = ptr[offset + 2]
                        let b3 = ptr[offset + 3]
                        // 14-bit LE: FF 1F 00 E8
                        if b0 == 0xFF && b1 == 0x1F && b2 == 0x00 && b3 == 0xE8 { return true }
                        // 14-bit BE: 1F FE E8 00
                        if b0 == 0x1F && b1 == 0xFE && b2 == 0xE8 && b3 == 0x00 { return true }
                        // 16-bit LE: FE 7F 01 80
                        if b0 == 0xFE && b1 == 0x7F && b2 == 0x01 && b3 == 0x80 { return true }
                        // 16-bit BE: 7F FE 80 01
                        if b0 == 0x7F && b1 == 0xFE && b2 == 0x80 && b3 == 0x01 { return true }
                    }
                    return false
                }
                offset += chunkSize
                if chunkSize % 2 != 0 { offset += 1 }
            }
            return false
        }
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

