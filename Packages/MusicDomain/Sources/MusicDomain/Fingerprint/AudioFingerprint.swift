//
//  AudioFingerprint.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine & Acoustic Evidence Pipeline.
//

import Foundation

// MARK: - Exact Audio Signature (Exactness Evidence)

/// A deterministic exact-content signature computed from decoded PCM samples or canonical file bytes.
///
/// Role: **Exactness Evidence**
/// - Local 0ms duplicate detection & deduplication
/// - File move / rename tracking without audio re-indexing
/// - Content-addressed caching of artwork, tags, and playback properties
public struct ExactAudioSignature: Sendable, Equatable, Hashable, Codable {
    /// The computed hex hash string (e.g. SHA-256).
    public let value: String
    /// The exact playback duration in seconds.
    public let duration: TimeInterval
    /// The signature algorithm identifier (e.g. "sha256-pcm-v1", "sha256-file-v1").
    public let algorithm: String

    public init(value: String, duration: TimeInterval, algorithm: String = "sha256-pcm-v1") {
        self.value = value
        self.duration = duration
        self.algorithm = algorithm
    }

    /// Backward-compatibility alias for legacy code expecting `fingerprint`.
    public var fingerprint: String { value }
}

/// Abstract contract for generating an exact audio content signature.
public protocol ExactAudioSignatureExtracting: Sendable {
    func generateSignature(for fileURL: URL) async throws -> ExactAudioSignature
}

// MARK: - Acoustic Fingerprint (Acoustic Similarity Evidence)

/// A perceptual acoustic fingerprint representing continuous audio wave features (Chromaprint).
///
/// Role: **Acoustic Similarity Evidence**
/// - Cross-codec and cross-container recognition (FLAC ↔ MP3 ↔ AAC)
/// - Resilient to psychoacoustic encoding variations and sample rate differences
/// - Query input for external public AcoustID services
public struct AcousticFingerprint: Sendable, Equatable, Hashable, Codable {
    /// The Chromaprint compressed base64 representation.
    public let value: String
    /// The exact playback duration in seconds.
    public let duration: TimeInterval
    /// The acoustic algorithm identifier (e.g. "chromaprint-v1").
    public let algorithm: String

    public init(value: String, duration: TimeInterval, algorithm: String = "chromaprint-v1") {
        self.value = value
        self.duration = duration
        self.algorithm = algorithm
    }

    /// Backward-compatibility alias for `fingerprint`.
    public var fingerprint: String { value }

    public init(fingerprint: String, duration: TimeInterval, algorithm: String = "chromaprint-v1") {
        self.value = fingerprint
        self.duration = duration
        self.algorithm = algorithm
    }
}

/// Abstract contract for asynchronous acoustic fingerprint generation.
public protocol AcousticFingerprintExtracting: Sendable {
    /// Generates an acoustic fingerprint for an audio file at the specified URL.
    func generateFingerprint(for fileURL: URL) async throws -> AcousticFingerprint
}
