//
//  AudioCodecBackend.swift
//  MSRU
//

import Foundation


nonisolated struct PCMStreamFormat: Sendable {

    let sampleRate: Double

    let channels: UInt32

    let channelLayoutMask: UInt64

    let duration: TimeInterval?

    let bitRate: Int64

    let canSeek: Bool

    let formatHint: String


    nonisolated init(
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


nonisolated struct PCMFrameBlock: Sendable {

    let channels: [[Float]]

    let frameCount: Int


    var channelCount: Int {
        channels.count
    }

    var left: [Float] {
        channels.isEmpty ? [] : channels[0]
    }

    var right: [Float] {
        channels.count > 1 ? channels[1] : (channels.first ?? [])
    }


    nonisolated init(
        channels: [[Float]],
        frameCount: Int
    ) {
        self.channels = channels
        self.frameCount = frameCount
    }

    nonisolated init(
        left: [Float],
        right: [Float],
        frameCount: Int
    ) {
        self.channels = [left, right]
        self.frameCount = frameCount
    }
}


protocol PCMDecodeSession: Sendable {

    func read(
        maxFrames: Int
    ) async throws -> PCMFrameBlock?


    func seek(
        to seconds: TimeInterval
    ) async throws


    func close() async
}


struct AudioCodecOpenResult: Sendable {

    let format: PCMStreamFormat

    let session: any PCMDecodeSession
}


protocol AudioCodecBackend: Sendable {

    var id: String { get }


    func canDecode(
        _ url: URL
    ) -> Bool


    func open(
        _ url: URL
    ) async throws -> AudioCodecOpenResult
}


// MARK: - Extended Formats

nonisolated enum ExtendedAudioFormatSupport {

    static let extensions: Set<String> = [
        "dts",
        "dtshd",
        "ape",
        "dsf",
        "dff"
    ]


    static func supports(
        _ url: URL
    ) -> Bool {
        extensions.contains(
            url.pathExtension.lowercased()
        )
    }
}
