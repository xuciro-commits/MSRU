//
//  FingerprintTests.swift
//  MSRUTests
//
//  Canonical audio signature & fingerprint tests:
//  Exact Audio Signature (!= Acoustic Fingerprint), algorithm distinction,
//  local deterministic Chromaprint extraction, cache invalidation heuristics,
//  and local fingerprint registry sanitization.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU
import MusicDomain

@Suite("Audio Fingerprint & Signature Contracts")
struct FingerprintTests {

    @Test
    func exactSignatureAndAcousticFingerprintUseDistinctAlgorithmIdentities() {
        // Arrange
        let exactSig = ExactAudioSignature(value: "sha256_mock_sig", duration: 180.0, algorithm: "sha256-pcm-v1")
        let acousticFP = AcousticFingerprint(value: "chromaprint_mock_fp", duration: 180.0, algorithm: "chromaprint-v1")

        // Assert: Exact signature (Exactness Evidence) != Acoustic fingerprint (Acoustic Evidence)
        #expect(exactSig.algorithm != acousticFP.algorithm)
        #expect(exactSig.algorithm == "sha256-pcm-v1")
        #expect(acousticFP.algorithm == "chromaprint-v1")
    }

    @Test
    func exactAudioSignatureIsDeterministicForIdenticalAudioContent() async throws {
        // Arrange: Generate deterministic WAV audio fixture
        let wav1 = try Fixtures.createDeterministicWAV(durationSeconds: 0.5, frequencyHz: 440.0)
        defer { try? FileManager.default.removeItem(at: wav1.deletingLastPathComponent()) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let wav2 = tempDir.appendingPathComponent("copy.wav")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.copyItem(at: wav1, to: wav2)

        let extractor = AcoustIDFingerprintExtractor()

        // Act
        let sig1 = try await extractor.generateSignature(for: wav1)
        let sig2 = try await extractor.generateSignature(for: wav2)

        // Assert: Identical audio bytes produce the exact same deterministic signature
        #expect(sig1.value == sig2.value)
        #expect(sig1.duration == sig2.duration)
        #expect(sig1.algorithm == "sha256-pcm-v1")
        #expect(!sig1.value.isEmpty)
    }

    @Test
    func chromaprintExtractsValidLocalAcousticFingerprintFromFixture() async throws {
        // Arrange: Generate deterministic PCM audio fixture
        let wavURL = try Fixtures.createDeterministicWAV(durationSeconds: 1.0, sampleRate: 44100, frequencyHz: 880.0)
        defer { try? FileManager.default.removeItem(at: wavURL.deletingLastPathComponent()) }

        let chromaprintExtractor = ChromaprintFingerprintExtractor()

        // Act: Extract acoustic fingerprint using native Chromaprint and Accelerate vDSP
        let fp = try await chromaprintExtractor.generateFingerprint(for: wavURL)

        // Assert: Non-empty Base64 Chromaprint fingerprint, valid duration, distinct algorithm
        #expect(!fp.value.isEmpty)
        #expect(fp.duration > 0.0)
        #expect(fp.algorithm == "chromaprint-v1")
    }

    @Test
    func audioFileSignatureValidatesUnmodifiedFilesAndDetectsMutations() throws {
        // Arrange
        let wavURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: wavURL.deletingLastPathComponent()) }

        guard let signature = AudioFileSignature(fileURL: wavURL) else {
            Issue.record("Failed to create AudioFileSignature")
            return
        }

        // Assert 1: Signature matches current file state
        #expect(signature.matches(fileURL: wavURL))

        // Act: Mutate the file by appending bytes
        let handle = try FileHandle(forWritingTo: wavURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x00, 0x01, 0x02, 0x03]))
        try handle.close()

        // Assert 2: Mutated file no longer matches original signature
        #expect(!signature.matches(fileURL: wavURL))
    }

    @Test
    func localFingerprintRegistrySanitizesGenericFolderAlbums() async {
        // Arrange: Create registry and record with generic album title "71-音乐库"
        let registry = LocalFingerprintRegistry()
        let item = FingerprintRegistrationItem(
            fingerprint: "test_fp_generic_album",
            duration: 180.0,
            title: "晴天",
            artist: "周杰伦",
            album: "71-音乐库",
            trackNumber: 4
        )

        // Act
        await registry.registerBatch([item])

        // Assert: Lookup sanitizes and strips generic folder name
        let found = await registry.lookup(fingerprint: "test_fp_generic_album", duration: 180.0)
        #expect(found != nil)
        #expect(found?.title == "晴天")
        #expect(found?.artist == "周杰伦")
        #expect(found?.album == nil)
    }
}
