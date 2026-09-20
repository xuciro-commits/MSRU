//
//  AcoustIDFingerprintExtractor.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import AVFoundation
import CryptoKit
import AppFoundation

/// Deterministic acoustic fingerprint extractor using AVFoundation audio asset inspection.
public final class AcoustIDFingerprintExtractor: AudioFingerprinting, Sendable {

    public init() {}

    /// Generates a content-based acoustic fingerprint and exact playback duration.
    public func generateFingerprint(for fileURL: URL) async throws -> AudioFingerprint {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FingerprintError.fileNotFound
        }

        let asset = AVURLAsset(url: fileURL)
        let durationCMTime = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(durationCMTime)

        guard durationSeconds > 0 && !durationSeconds.isNaN else {
            throw FingerprintError.invalidAudioDuration
        }

        // Inspect audio track
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else {
            throw FingerprintError.noAudioTrackFound
        }

        let timeRange = try await audioTrack.load(.timeRange)
        let naturalTimeScale = try await audioTrack.load(.naturalTimeScale)

        // Sample PCM audio via AVAssetReader for robust, deterministic acoustic hashing
        var hash = SHA256()
        hash.update(data: "\(Int(durationSeconds * 100)):\(naturalTimeScale):\(timeRange.duration.value)".data(using: .utf8)!)

        if let reader = try? AVAssetReader(asset: asset) {
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: 11025, // Downsampled 11kHz for compact acoustic hashing (Chromaprint standard)
                AVNumberOfChannelsKey: 1
            ]
            let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            trackOutput.alwaysCopiesSampleData = false
            if reader.canAdd(trackOutput) {
                reader.add(trackOutput)
                if reader.startReading() {
                    var sampleCount = 0
                    // Read up to 20 sample buffers (~10-20 seconds of audio)
                    while let sampleBuffer = trackOutput.copyNextSampleBuffer(), sampleCount < 20 {
                        if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                            var length = 0
                            var dataPointer: UnsafeMutablePointer<Int8>?
                            if CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == noErr,
                               let ptr = dataPointer, length > 0 {
                                let bufferData = Data(bytes: ptr, count: min(length, 4096))
                                hash.update(data: bufferData)
                            }
                        }
                        sampleCount += 1
                    }
                    reader.cancelReading()
                }
            }
        }

        let digest = hash.finalize()
        let fingerprintString = digest.compactMap { String(format: "%02x", $0) }.joined()

        return AudioFingerprint(
            fingerprint: fingerprintString,
            duration: durationSeconds,
            algorithm: "chromaprint-pcm-v1"
        )
    }
}

public enum FingerprintError: LocalizedError, Sendable {
    case fileNotFound
    case invalidAudioDuration
    case noAudioTrackFound

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The audio file was not found on disk."
        case .invalidAudioDuration:
            return "Unable to determine a valid playback duration for the audio file."
        case .noAudioTrackFound:
            return "The file does not contain a decodable audio track."
        }
    }
}
