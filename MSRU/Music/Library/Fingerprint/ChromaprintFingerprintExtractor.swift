//
//  ChromaprintFingerprintExtractor.swift
//  MSRU
//
//  Created for Acoustic Fingerprint & AcoustID Integration.
//

import Foundation
import ChromaSwift
import AppFoundation

/// Real AcoustID-compatible acoustic fingerprint extractor using native Chromaprint and Apple Accelerate (vDSP).
public final class ChromaprintFingerprintExtractor: AcousticFingerprintExtracting, Sendable {

    public init() {}

    /// Generates a genuine Chromaprint Base64 acoustic fingerprint for AcoustID web queries.
    public func generateFingerprint(for fileURL: URL) async throws -> AcousticFingerprint {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FingerprintError.fileNotFound
        }

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // ChromaSwift AudioFingerprint defaults to .test2 algorithm which is the
        // only format accepted by the public AcoustID Web Service API.
        let chromaFP = try ChromaSwift.AudioFingerprint(from: fileURL, algorithm: .test2)

        return AcousticFingerprint(
            value: chromaFP.fingerprint,
            duration: chromaFP.duration,
            algorithm: "chromaprint-v1"
        )
    }
}
