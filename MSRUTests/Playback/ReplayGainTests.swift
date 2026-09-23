import Foundation
import Testing
@testable import MSRU

@Suite("R128 loudness and gain contracts")
struct ReplayGainTests {
    @Test("EBU stereo 1 kHz tone at -23 dBFS measures -23 LUFS")
    func referenceTone() throws {
        let rate = 48_000.0
        let amplitude = Float(pow(10.0, -23.0 / 20.0))
        let count = Int(rate * 2)
        let samples = (0..<count).map { frame in
            amplitude * sin(Float(2 * Double.pi * 1_000 * Double(frame) / rate))
        }
        var meter = try #require(R128Meter(sampleRate: rate, channels: 2))
        for start in stride(from: 0, to: count, by: 8192) {
            let end = min(start + 8192, count)
            let section = Array(samples[start..<end])
            meter.append(PCMFrameBlock(channels: [section, section], frameCount: section.count))
        }
        let result = try #require(meter.measurement())
        #expect(abs(result.integratedLUFS - (-23)) < 0.15)
        #expect(abs(result.samplePeak - Double(amplitude)) < 0.001)
    }

    @Test("Silence is gated and missing measurements do not change gain")
    func silenceAndFallback() throws {
        var meter = try #require(R128Meter(sampleRate: 48_000, channels: 2))
        meter.append(PCMFrameBlock(channels: [Array(repeating: 0, count: 48_000),
                                               Array(repeating: 0, count: 48_000)], frameCount: 48_000))
        #expect(meter.measurement() == nil)
        #expect(ReplayGainPolicy.gainDB(for: nil) == 0)
        let loud = R128Measurement(integratedLUFS: -35, samplePeak: 0.95, duration: 10)
        #expect(ReplayGainPolicy.gainDB(for: loud) < 0)
    }

    @Test("Analysis persists by file signature and invalidates changed files")
    func scanCache() async throws {
        let url = try Fixtures.createDeterministicWAV(durationSeconds: 1.0)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let service = ReplayGainService(db: try TestDatabase.makeEphemeral())
        #expect(try await service.cachedTrack(for: url) == nil)
        let measured = try #require(try await service.analyzeTrack(url))
        #expect(measured.integratedLUFS.isFinite)
        #expect(try await service.cachedTrack(for: url) == measured)
        let nextDate = Date(timeIntervalSinceNow: 10)
        try FileManager.default.setAttributes([.modificationDate: nextDate], ofItemAtPath: url.path)
        #expect(try await service.cachedTrack(for: url) == nil)
    }
}
