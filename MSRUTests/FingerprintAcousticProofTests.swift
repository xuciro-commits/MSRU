//
//  FingerprintAcousticProofTests.swift
//  MSRUTests
//
//  Empirical test suite demonstrating the distinction between
//  ExactAudioSignature (PCM SHA-256) and AcousticFingerprint (Chromaprint).
//

import Testing
import Foundation
import AVFoundation
import AppFoundation
@testable import MSRU

@Suite("Acoustic Fingerprint vs Exact Signature Proof")
struct FingerprintAcousticProofTests {

    /// Helper to generate a deterministic 3-second stereo sine wave WAV file.
    private func createSineWaveAudio(at url: URL, sampleRate: Double = 44100, duration: Double = 3.0) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw FingerprintError.invalidAudioDuration
        }
        buffer.frameLength = frameCount

        let twoPi = 2.0 * Double.pi
        let frequency = 440.0 // 440 Hz standard A tone
        for frame in 0..<Int(frameCount) {
            let sampleVal = Float(sin(twoPi * frequency * Double(frame) / sampleRate) * 0.5)
            buffer.floatChannelData?[0][frame] = sampleVal
            buffer.floatChannelData?[1][frame] = sampleVal
        }
        try audioFile.write(from: buffer)
    }

    /// Helper to transcode WAV to AAC (M4A) or other format using AVAssetExportSession
    private func transcode(source: URL, destination: URL, outputFileType: AVFileType) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw FingerprintError.noAudioTrackFound
        }
        session.outputURL = destination
        session.outputFileType = outputFileType
        await session.export()
        if let error = session.error {
            throw error
        }
    }

    @Test("Exact same file at different paths produces identical signature (Content/Move Evidence)")
    func testSameFileDifferentPathProducesIdenticalSignature() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let originalURL = tempDir.appendingPathComponent("original.wav")
        let movedURL = tempDir.appendingPathComponent("moved_and_renamed.wav")

        try createSineWaveAudio(at: originalURL)
        try FileManager.default.copyItem(at: originalURL, to: movedURL)

        let extractor = AcoustIDFingerprintExtractor()
        let sig1 = try await extractor.generateFingerprint(for: originalURL)
        let sig2 = try await extractor.generateFingerprint(for: movedURL)

        // Exact Content Signature matches 100% across paths/names
        #expect(sig1.fingerprint == sig2.fingerprint)
        #expect(sig1.fingerprint.count == 64) // SHA-256 hex string length
        print("[Proof] Exact Move/Rename signature matched: \(sig1.fingerprint)")
    }

    @Test("Cross-format lossy compression (WAV vs M4A) produces DIFFERENT PCM SHA-256 signatures")
    func testCrossFormatLossyBreaksPCMSHA256() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wavURL = tempDir.appendingPathComponent("tone.wav")
        let m4aURL = tempDir.appendingPathComponent("tone.m4a")

        try createSineWaveAudio(at: wavURL)
        try await transcode(source: wavURL, destination: m4aURL, outputFileType: .m4a)

        let extractor = AcoustIDFingerprintExtractor()
        let wavSig = try await extractor.generateFingerprint(for: wavURL)
        let m4aSig = try await extractor.generateFingerprint(for: m4aURL)

        print("[Proof] WAV signature: \(wavSig.fingerprint)")
        print("[Proof] M4A signature: \(m4aSig.fingerprint)")

        // EMPIRICAL PROOF:
        // Even though both files contain the exact same 440Hz sine wave tone,
        // psychoacoustic encoding alters raw PCM sample bits, causing SHA-256 to completely diverge!
        #expect(wavSig.fingerprint != m4aSig.fingerprint)
    }

    @Test("Public AcoustID Web API rejects PCM SHA-256 with invalid fingerprint error (code 3)")
    func testAcoustIDRejectsPCMSHA256() async throws {
        let clientKey = "cSpUJKpD"
        let dummySHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let endpoint = "https://api.acoustid.org/v2/lookup"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client=\(clientKey)&duration=180&fingerprint=\(dummySHA256)&meta=recordings"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            Issue.record("Invalid HTTP response")
            return
        }

        #expect(http.statusCode == 200 || http.statusCode == 400)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String,
           let error = json["error"] as? [String: Any] {
            #expect(status == "error")
            #expect(error["code"] as? Int == 3)
            #expect((error["message"] as? String)?.contains("invalid fingerprint") == true)
            print("[Proof] AcoustID API correctly rejected SHA256: status=\(status), error=\(error)")
        }
    }

    @Test("ChromaprintFingerprintExtractor generates real AcoustID-compatible Chromaprint Base64")
    func testChromaprintExtractorGeneratesValidChromaprint() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wavURL = tempDir.appendingPathComponent("tone.wav")
        try createSineWaveAudio(at: wavURL, duration: 5.0)

        let extractor = ChromaprintFingerprintExtractor()
        let chromaFP = try await extractor.generateFingerprint(for: wavURL)

        #expect(!chromaFP.value.isEmpty)
        #expect(chromaFP.algorithm == "chromaprint-v1")
        #expect(chromaFP.duration > 4.5 && chromaFP.duration < 5.5)

        // Chromaprint Base64 format verification:
        // Chromaprint generates base64-encoded compressed bitstream starting with header bits (typically AQAA...)
        #expect(chromaFP.value.hasPrefix("AQAA") || chromaFP.value.hasPrefix("AQA"))
        print("[Proof] Real Chromaprint generated: length=\(chromaFP.value.count), prefix=\(chromaFP.value.prefix(16))...")
    }

    @Test("AcoustID Web API accepts genuine Chromaprint with status ok")
    func testChromaprintQueryAcceptedByAcoustID() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wavURL = tempDir.appendingPathComponent("tone.wav")
        try createSineWaveAudio(at: wavURL, duration: 5.0)

        let extractor = ChromaprintFingerprintExtractor()
        let chromaFP = try await extractor.generateFingerprint(for: wavURL)

        let clientKey = "cSpUJKpD"
        let endpoint = "https://api.acoustid.org/v2/lookup"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url, timeoutInterval: 12.0)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client=\(clientKey)&duration=\(Int(chromaFP.duration))&fingerprint=\(chromaFP.value)&meta=recordings"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            Issue.record("Invalid HTTP response")
            return
        }

        #expect(http.statusCode == 200)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            // EMPIRICAL PROOF:
            // AcoustID successfully accepted our Chromaprint! status is "ok" (no code 3 invalid fingerprint)
            #expect(status == "ok")
            let results = json["results"] as? [[String: Any]] ?? []
            print("[Proof] AcoustID API SUCCESS with real Chromaprint: status=\(status), resultsCount=\(results.count)")
        }
    }

    @Test("ExactAudioSignatureService correctly indexes with sha256-pcm-v1 algorithm")
    func testExactAudioSignatureServiceAndRegistry() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wavURL = tempDir.appendingPathComponent("test_track.wav")
        try createSineWaveAudio(at: wavURL, duration: 3.0)

        let regStorage = tempDir.appendingPathComponent("signatures.json")
        let registry = LocalAudioSignatureRegistry(storageURL: regStorage)
        let service = ExactAudioSignatureService(registry: registry)

        let sig = try await service.signature(for: wavURL)
        #expect(sig.algorithm == "sha256-pcm-v1")
        #expect(sig.value.count == 64)

        let track = LocalTrack(fileURL: wavURL, title: "Test Tone", artist: "Synth", duration: sig.duration)
        let batchResult = await service.indexTracks([track])
        #expect(batchResult.newlyComputedCount == 1)

        let records = await registry.records
        #expect(records.count == 1)
        #expect(records.first?.algorithm == "sha256-pcm-v1")
        #expect(records.first?.fingerprint == sig.value)
    }
}

