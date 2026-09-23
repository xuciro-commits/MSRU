import AVFoundation
import Foundation
import MusicDomain
import MusicLibrary

/// Decodes Apple-supported local files into the same planar Float32 blocks as
/// the extended codec path, so the playback node can schedule album tracks
/// without replacing its audio engine.
public nonisolated struct AppleAudioFileDecoder: AudioCodecBackend {
    public let id = "apple-audio-file"

    public func canDecode(_ url: URL) -> Bool {
        url.isFileURL && !ExtendedAudioFormatSupport.supports(url)
    }

    public func open(_ url: URL) async throws -> AudioCodecOpenResult {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let audioFormat = file.processingFormat
        let duration = Double(file.length) / audioFormat.sampleRate
        return AudioCodecOpenResult(
            format: PCMStreamFormat(
                sampleRate: audioFormat.sampleRate,
                channels: audioFormat.channelCount,
                duration: duration,
                bitRate: 0,
                formatHint: url.pathExtension.uppercased()
            ),
            session: AppleAudioFileSession(file: file)
        )
    }

    nonisolated public init() {}
}

private actor AppleAudioFileSession: PCMDecodeSession {
    private var file: AVAudioFile?

    public init(file: AVAudioFile) {
        self.file = file
    }

    public func read(maxFrames: Int) throws -> PCMFrameBlock? {
        guard let file else { return nil }
        let remaining = file.length - file.framePosition
        guard remaining > 0 else { return nil }
        let capacity = AVAudioFrameCount(min(Int64(maxFrames), remaining))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
            throw AppleAudioFileError.bufferAllocationFailed
        }
        try file.read(into: buffer, frameCount: capacity)
        guard buffer.frameLength > 0 else { return nil }
        guard let data = buffer.floatChannelData else { throw AppleAudioFileError.invalidFormat }
        let count = Int(buffer.frameLength)
        let channels = (0..<Int(file.processingFormat.channelCount)).map { index in
            Array(UnsafeBufferPointer(start: data[index], count: count))
        }
        return PCMFrameBlock(channels: channels, frameCount: count)
    }

    public func seek(to seconds: TimeInterval) throws {
        guard let file else { return }
        let frame = AVAudioFramePosition(max(0, seconds) * file.processingFormat.sampleRate)
        file.framePosition = min(frame, file.length)
    }

    public func close() {
        file = nil
    }
}

private enum AppleAudioFileError: Error {
    case bufferAllocationFailed
    case invalidFormat
}
