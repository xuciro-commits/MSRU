//
//  AudioAsset.swift
//  MSRU
//

import Foundation

/// A concrete physical audio file stored on local or attached storage.
///
/// Distinct from `Recording` (the performance) and `MusicTrack` (the disc slot).
/// Multiple AudioAssets may represent the same Recording (e.g. FLAC 24/96 master vs MP3 mobile copy).
nonisolated public struct AudioAsset: Identifiable, Hashable, Codable, Sendable {

    /// Unique asset identifier.
    public let id: String

    /// Physical file location on local disk.
    public let fileURL: URL

    /// File size in bytes.
    public let fileSize: Int64

    /// Cryptographic SHA256 checksum for byte-level duplicate detection.
    public var sha256: String?

    /// Audio container/codec format string (e.g. "FLAC", "WAV", "AAC", "MP3").
    public let format: String

    /// Quantization bit depth (e.g. "16-bit", "24-bit").
    public let bitDepth: String?

    /// Sampling rate in Hz (e.g. 44100, 48000, 96000, 192000).
    public let sampleRate: Double

    /// Approximate or exact bitrate in kilobits per second.
    public let bitrateKbps: Int?

    /// Playback duration in seconds.
    public let duration: TimeInterval

    /// Chromaprint / AcoustID fingerprint hash string for content-based recognition.
    public var acoustID: String?

    /// Associated Recording entity MBID, once identified.
    public var recordingID: String?

    public init(
        id: String = UUID().uuidString,
        fileURL: URL,
        fileSize: Int64 = 0,
        sha256: String? = nil,
        format: String,
        bitDepth: String? = nil,
        sampleRate: Double = 44100,
        bitrateKbps: Int? = nil,
        duration: TimeInterval = 0,
        acoustID: String? = nil,
        recordingID: String? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.sha256 = sha256
        self.format = format.uppercased()
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        self.bitrateKbps = bitrateKbps
        self.duration = duration
        self.acoustID = acoustID
        self.recordingID = recordingID
    }

    /// Whether this asset represents a lossless encoding.
    public var isLossless: Bool {
        ["FLAC", "WAV", "AIFF", "AIF", "ALAC", "DTS"].contains(format)
    }

    /// Whether this asset meets high-resolution audio criteria (> 48 kHz or 24-bit).
    public var isHiRes: Bool {
        sampleRate > 48000 || bitDepth == "24-bit"
    }
}
