//
//  LocalFingerprintRegistryTests.swift
//  MSRUTests
//
//  Created for Local Acoustic Fingerprint Memory testing.
//

import Testing
import Foundation
@testable import MSRU

@MainActor
struct LocalFingerprintRegistryTests {

    @Test
    func registerAndLookupAcousticFingerprint() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_fingerprints.json")
        let registry = LocalFingerprintRegistry(storageURL: storageURL)

        #expect(registry.records.isEmpty)

        // 1. Register a track
        let testFP = "sha256_mock_hash_wang_leehom_01"
        registry.register(
            fingerprint: testFP,
            duration: 278.4,
            title: "你不知道的事",
            artist: "王力宏",
            album: "十八般武艺",
            trackNumber: 1,
            releaseMBID: "mbid_rel_123",
            recordingMBID: "mbid_rec_456"
        )

        #expect(registry.records.count == 1)

        // 2. Exact lookup
        let matched = registry.lookup(fingerprint: testFP, duration: 278.0, tolerance: 2.0)
        #expect(matched != nil)
        #expect(matched?.title == "你不知道的事")
        #expect(matched?.artist == "王力宏")
        #expect(matched?.album == "十八般武艺")

        // 3. Registering again updates fields without mutating matchCount
        registry.register(
            fingerprint: testFP,
            duration: 278.4,
            title: "你不知道的事 (重命名)",
            artist: "王力宏"
        )
        #expect(registry.records.count == 1)
        #expect(registry.records.first?.matchCount == 0)
        #expect(registry.records.first?.title == "你不知道的事 (重命名)")

        // 4. Calling recordMatch increments matchCount
        registry.recordMatch(fingerprint: testFP)
        #expect(registry.records.first?.matchCount == 1)

        // 5. Persistence across recreation
        let reopened = LocalFingerprintRegistry(storageURL: storageURL)
        #expect(reopened.records.count == 1)
        #expect(reopened.lookup(fingerprint: testFP, duration: 278.4)?.title == "你不知道的事 (重命名)")
        #expect(reopened.records.first?.matchCount == 1)

        // 6. Remove
        reopened.remove(fingerprint: testFP)
        #expect(reopened.records.isEmpty)
    }

    @Test
    func assetCacheValidationAndMultiPathSharing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_fingerprints.json")
        let registry = LocalFingerprintRegistry(storageURL: storageURL)

        let fileA = tempDir.appendingPathComponent("trackA.flac")
        let fileB = tempDir.appendingPathComponent("trackB.flac")
        let dummyData = Data(repeating: 0x42, count: 2048)
        try dummyData.write(to: fileA)
        try dummyData.write(to: fileB)

        let commonFingerprint = "fp_common_audio_stream_123"

        // Register both distinct files with the same acoustic fingerprint
        registry.register(
            fingerprint: commonFingerprint,
            duration: 180.0,
            title: "Common Song",
            artist: "Common Artist",
            fileURL: fileA
        )
        registry.register(
            fingerprint: commonFingerprint,
            duration: 180.0,
            title: "Common Song",
            artist: "Common Artist",
            fileURL: fileB
        )

        // Exactly one acoustic fingerprint record exists
        #expect(registry.records.count == 1)
        #expect(registry.records.first?.fingerprint == commonFingerprint)

        // Both distinct file paths have valid cached fingerprints
        #expect(registry.cachedFingerprint(for: fileA) == commonFingerprint)
        #expect(registry.cachedFingerprint(for: fileB) == commonFingerprint)
        #expect(registry.hasValidRecord(for: fileA))
        #expect(registry.hasValidRecord(for: fileB))

        // Modify fileA on disk (change size)
        let modifiedData = Data(repeating: 0x43, count: 4096)
        try modifiedData.write(to: fileA)

        // fileA is no longer valid, but fileB remains completely valid!
        #expect(registry.cachedFingerprint(for: fileA) == nil)
        #expect(!registry.hasValidRecord(for: fileA))
        #expect(registry.cachedFingerprint(for: fileB) == commonFingerprint)
        #expect(registry.hasValidRecord(for: fileB))
    }

    @Test
    func registerWithArtworkAndPersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_fingerprints.json")
        let registry = LocalFingerprintRegistry(storageURL: storageURL)

        let mockJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(42), count: 64))
        let fp = "sha256_mock_artwork_track"

        registry.register(
            fingerprint: fp,
            duration: 200.0,
            title: "山雀",
            artist: "万能青年旅店",
            album: "冀西南林路行",
            artworkData: mockJPEG
        )

        let lookedUp = registry.lookup(fingerprint: fp, duration: 200.0)
        #expect(lookedUp != nil)
        #expect(lookedUp?.artworkData == mockJPEG)

        let reloaded = LocalFingerprintRegistry(storageURL: storageURL)
        #expect(reloaded.lookup(fingerprint: fp, duration: 200.0)?.artworkData == mockJPEG)
    }

    @Test
    func extractArtworkFromDirectoryCoverFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mockJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(99), count: 64))
        let coverURL = tempDir.appendingPathComponent("cover.jpg")
        try mockJPEG.write(to: coverURL)

        let extracted = LocalArtworkExtractor.extractFromDirectory(folderURL: tempDir)
        #expect(extracted == mockJPEG)
        #expect(LocalArtworkExtractor.isValidImageData(mockJPEG))
    }
}
