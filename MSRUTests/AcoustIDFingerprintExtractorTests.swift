//
//  AcoustIDFingerprintExtractorTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct AcoustIDFingerprintExtractorTests {

    @Test
    func generateFingerprintFromRealLocalAudioFile() async throws {
        let realAudioURL = URL(fileURLWithPath: "/Users/ciro/Music/Music/Media.localized/Music/Adele/21/Rolling In The Deep.m4a")
        guard FileManager.default.fileExists(atPath: realAudioURL.path) else {
            return
        }

        let extractor = AcoustIDFingerprintExtractor()
        let fp = try await extractor.generateFingerprint(for: realAudioURL)

        #expect(fp.duration > 200.0 && fp.duration < 300.0)
        #expect(!fp.fingerprint.isEmpty)
        #expect(fp.algorithm == "chromaprint-pcm-v1")
    }

    @Test
    func nonExistentFileThrowsError() async {
        let missingURL = URL(fileURLWithPath: "/nonexistent/path/missing.flac")
        let extractor = AcoustIDFingerprintExtractor()

        do {
            _ = try await extractor.generateFingerprint(for: missingURL)
            Issue.record("Expected error for missing file")
        } catch {
            #expect(error is FingerprintError)
        }
    }
}
