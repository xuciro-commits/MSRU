//
//  FFmpegCodecBackend.swift
//  MSRU
//

import Foundation
import MSRUCodecFFmpeg


struct FFmpegCodecBackend: AudioCodecBackend {

    let id = "ffmpeg"


    func canDecode(
        _ url: URL
    ) -> Bool {
        ExtendedAudioFormatSupport.supports(url)
    }


    func open(
        _ url: URL
    ) async throws -> AudioCodecOpenResult {

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
}


// MARK: - Session

private actor FFmpegPCMDecodeSession: PCMDecodeSession {

    private let decoder: FFmpegAudioDecoder


    init(decoder: FFmpegAudioDecoder) {
        self.decoder = decoder
    }


    func read(
        maxFrames: Int
    ) async throws -> PCMFrameBlock? {

        guard let block = try decoder.read(maxFrames: maxFrames) else {
            return nil
        }

        return PCMFrameBlock(
            channels: block.channels,
            frameCount: block.frameCount
        )
    }


    func seek(
        to seconds: TimeInterval
    ) async throws {
        try decoder.seek(to: seconds)
    }


    func close() async {
        decoder.close()
    }
}
