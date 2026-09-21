//
//  AudioFingerprintServiceTests.swift
//  MSRUTests
//
//  Created for Decoupled Audio Fingerprint Service & Indexing Tests.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU
@Suite(.serialized)
struct AudioFingerprintServiceTests {

    private struct MockFingerprinter: AudioFingerprinting, Sendable {
        let executionCounter: ExecutionCounter

        final class ExecutionCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int {
                lock.lock()
                defer { lock.unlock() }
                return _count
            }
            func increment() {
                lock.lock()
                defer { lock.unlock() }
                _count += 1
            }
        }

        func generateFingerprint(for fileURL: URL) async throws -> AudioFingerprint {
            executionCounter.increment()
            // Simulate minimal work
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return AudioFingerprint(fingerprint: "mock_fp_\(fileURL.lastPathComponent)", duration: 180.0)
        }
    }

    @Test
    func inFlightDeduplicationPreventsDuplicateExtraction() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test.flac")
        try Data(repeating: 0x55, count: 2048).write(to: fileURL)

        let counter = MockFingerprinter.ExecutionCounter()
        let fingerprinter = MockFingerprinter(executionCounter: counter)
        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)
        let service = AudioFingerprintService(fingerprinter: fingerprinter, registry: registry)

        // Launch two concurrent requests for the exact same URL
        async let first = service.fingerprint(for: fileURL)
        async let second = service.fingerprint(for: fileURL)

        let (fp1, fp2) = try await (first, second)
        #expect(fp1.fingerprint == fp2.fingerprint)
        #expect(counter.count == 1) // Only extracted once due to in-flight deduplication!
    }

    @Test
    func indexTracksSkipsCachedEntriesWithoutDecoding() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileA = tempDir.appendingPathComponent("trackA.flac")
        let fileB = tempDir.appendingPathComponent("trackB.flac")
        try Data(repeating: 0x11, count: 1024).write(to: fileA)
        try Data(repeating: 0x22, count: 1024).write(to: fileB)

        let counter = MockFingerprinter.ExecutionCounter()
        let fingerprinter = MockFingerprinter(executionCounter: counter)
        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)
        let service = AudioFingerprintService(fingerprinter: fingerprinter, registry: registry)

        let tracks = [
            LocalTrack(fileURL: fileA, title: "Track A", artist: "Artist A", duration: 180.0),
            LocalTrack(fileURL: fileB, title: "Track B", artist: "Artist B", duration: 180.0)
        ]

        // First pass: extracts both
        let result1 = await service.indexTracks(tracks)
        #expect(result1.totalReceived == 2)
        #expect(result1.extractedCount == 2)
        #expect(result1.skippedCachedCount == 0)
        #expect(counter.count == 2)

        // Second pass on unchanged files: should skip both!
        let result2 = await service.indexTracks(tracks)
        #expect(result2.totalReceived == 2)
        #expect(result2.extractedCount == 0)
        #expect(result2.skippedCachedCount == 2)
        #expect(counter.count == 2) // Unchanged!
    }

    @Test
    func batchedPersistenceMinimizesDiskWrites() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = MockFingerprinter.ExecutionCounter()
        let fingerprinter = MockFingerprinter(executionCounter: counter)
        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)
        let service = AudioFingerprintService(fingerprinter: fingerprinter, registry: registry)

        var tracks: [LocalTrack] = []
        for i in 1...12 {
            let fileURL = tempDir.appendingPathComponent("batch_\(i).flac")
            try Data(repeating: UInt8(i), count: 512).write(to: fileURL)
            tracks.append(LocalTrack(fileURL: fileURL, title: "Track \(i)", artist: "Artist", duration: 120.0))
        }

        let result = await service.indexTracks(tracks, chunkSize: 5)
        #expect(result.extractedCount == 12)

        // 12 tracks with chunk size 5 = 2 chunk writes (5 + 5) + 1 final flush write (2) = 3 total writes
        let writeCount = await registry.persistenceWriteCount
        #expect(writeCount == 3)
        #expect(await registry.records.count == 12)
    }

    @Test
    func indexingServiceOrchestrationLifecycle() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("orch_test.flac")
        try Data(repeating: 0x88, count: 1024).write(to: fileURL)

        let counter = MockFingerprinter.ExecutionCounter()
        let fingerprinter = MockFingerprinter(executionCounter: counter)
        let regStorage = tempDir.appendingPathComponent("reg.json")
        let registry = LocalFingerprintRegistry(storageURL: regStorage)
        let fpService = AudioFingerprintService(fingerprinter: fingerprinter, registry: registry)
        let indexingService = LocalLibraryIndexingService(fingerprintService: fpService, learnRules: false)

        let track = LocalTrack(fileURL: fileURL, title: "Orchestration Track", artist: "Orchestration Artist", duration: 150.0)

        #expect(await indexingService.currentStage == .idle)
        await indexingService.enqueue([track])

        // Wait for background indexing task to finish
        for _ in 0..<300 {
            if case .complete = await indexingService.currentStage {
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let finalStage = await indexingService.currentStage
        if case .complete(let total, let skipped) = finalStage {
            #expect(total == 1)
            #expect(skipped == 0)
        } else {
            Issue.record("Indexing service did not reach complete stage within deadline, got: \(finalStage)")
        }
    }
}
