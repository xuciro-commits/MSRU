//
//  AudioFingerprint.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation

/// A content-based acoustic fingerprint extracted from raw audio data.
public struct AudioFingerprint: Sendable, Equatable, Hashable, Codable {
    /// The computed fingerprint representation (e.g. Chromaprint compressed base64 or raw hash).
    public let fingerprint: String
    /// The exact duration in seconds over which the fingerprint was generated.
    public let duration: TimeInterval
    /// The identifier of the fingerprinting algorithm used (e.g. "chromaprint-v1", "pcm-waveform-v1").
    public let algorithm: String

    public init(fingerprint: String, duration: TimeInterval, algorithm: String = "chromaprint-v1") {
        self.fingerprint = fingerprint
        self.duration = duration
        self.algorithm = algorithm
    }
}

/// Abstract contract for asynchronous acoustic fingerprint generation.
public protocol AudioFingerprinting: Sendable {
    /// Generates an acoustic fingerprint for an audio file at the specified URL.
    func generateFingerprint(for fileURL: URL) async throws -> AudioFingerprint
}
