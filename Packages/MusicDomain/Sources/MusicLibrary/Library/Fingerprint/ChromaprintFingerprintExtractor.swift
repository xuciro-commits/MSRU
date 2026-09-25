//
//  ChromaprintFingerprintExtractor.swift
//  MSRU
//
//  Created for Acoustic Fingerprint & AcoustID Integration.
//

import Foundation
import ChromaSwift
import AppFoundation
import MusicDomain

/// Real AcoustID-compatible acoustic fingerprint extractor using native Chromaprint and Apple Accelerate (vDSP).
public final class ChromaprintFingerprintExtractor: AcousticFingerprintExtracting, Sendable {

    public init() {}

    /// Generates a genuine Chromaprint Base64 acoustic fingerprint for AcoustID web queries.
    ///
    /// Decoding a whole file and running Chromaprint takes up to seconds. This
    /// target's default isolation is the main actor, so the work runs in a
    /// detached task to keep it off the caller's executor.
    public func generateFingerprint(for fileURL: URL) async throws -> AcousticFingerprint {
        let computed = try await Task.detached(priority: .utility) { () throws -> (value: String, duration: Double)? in
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            // ChromaSwift AudioFingerprint defaults to .test2 algorithm which is the
            // only format accepted by the public AcoustID Web Service API.
            let chromaFP = try ChromaSwift.AudioFingerprint(from: fileURL, algorithm: .test2)
            return (chromaFP.fingerprint, chromaFP.duration)
        }.value

        guard let computed else {
            throw FingerprintError.fileNotFound
        }
        return AcousticFingerprint(
            value: computed.value,
            duration: computed.duration,
            algorithm: "chromaprint-v1"
        )
    }
}
