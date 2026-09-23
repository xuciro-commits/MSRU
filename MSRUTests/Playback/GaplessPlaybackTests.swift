import Foundation
import Testing
import MusicDomain
@testable import MSRU

@MainActor
@Suite("Local PCM album playback", .serialized)
struct GaplessPlaybackTests {
    @Test("Preseeked PCM playback resumes at its saved position and can seek again")
    func resumesFromPosition() async throws {
        let url = try Fixtures.createDeterministicWAV(durationSeconds: 0.6)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoded = try await AppleAudioFileDecoder().open(url)
        try await decoded.session.seek(to: 0.15)
        let engine = try await PCMPlaybackEngine(
            resource: PCMPlaybackResource(format: decoded.format, session: decoded.session),
            initialTime: 0.15
        )
        engine.volume = 0
        engine.play()
        for _ in 0..<20 where engine.currentTime <= 0.15 {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(engine.currentTime > 0.15)
        try await engine.seek(to: 0.3)
        for _ in 0..<20 where engine.currentTime <= 0.3 {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(engine.currentTime > 0.3)
        await engine.close()
    }

    @Test("Apple local provider decodes the file to PCM blocks")
    func localFileUsesPCM() async throws {
        let url = try Fixtures.createDeterministicWAV(durationSeconds: 0.2, channels: 2)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let request = PlaybackRequest(itemID: "test", source: .local, localFileURL: url)
        let resource = try await LocalPlaybackProvider().resolve(request)
        guard case .decodedPCM(let pcm) = resource.transport else {
            Issue.record("Expected a decoded PCM transport for a local WAV file")
            return
        }
        #expect(pcm.format.sampleRate == 44_100)
        #expect(pcm.format.channels == 2)
        let block = try await pcm.session.read(maxFrames: 512)
        #expect(block?.frameCount == 512)
        #expect(block?.channels.count == 2)
        var total = block?.frameCount ?? 0
        while let block = try await pcm.session.read(maxFrames: 512) {
            total += block.frameCount
        }
        #expect(total == 8_820)
        await pcm.session.close()
    }

    @Test("Compatible tracks advance on one PCM playback engine")
    func sameFormatAdvancesWithoutReplacingNode() async throws {
        let firstURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.35)
        let secondURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.35)
        defer {
            try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
        }

        let codec = AppleAudioFileDecoder()
        let first = try await codec.open(firstURL)
        let second = try await codec.open(secondURL)
        let engine = try await PCMPlaybackEngine(resource: PCMPlaybackResource(format: first.format, session: first.session))

        let nextResource = PlaybackResource(
            providerID: .local,
            transport: .decodedPCM(PCMPlaybackResource(format: second.format, session: second.session)),
            duration: second.format.duration
        )
        let queueID = UUID()
        var advanceCount = 0
        var endedCount = 0
        var failureMessage: String?
        engine.onAdvanced = { receivedID, _ in
            #expect(receivedID == queueID)
            advanceCount += 1
        }
        engine.onEnded = { endedCount += 1 }
        engine.onFailure = { failureMessage = $0.localizedDescription }
        #expect(engine.canPrepare(nextResource))
        engine.prepareNext(queueID: queueID, resource: nextResource)
        engine.play()

        for _ in 0..<120 where endedCount == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(advanceCount == 1)
        #expect(endedCount == 1)
        #expect(failureMessage == nil)
        #expect(engine.isPlaying == false)
        #expect(engine.format.duration == second.format.duration)
        await engine.close()
    }

    @Test("Different sample rates require the normal transport handoff")
    func differentFormatCannotBeQueuedOnSameNode() async throws {
        let firstURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.1, sampleRate: 44_100)
        let secondURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.1, sampleRate: 48_000)
        defer {
            try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
        }
        let codec = AppleAudioFileDecoder()
        let first = try await codec.open(firstURL)
        let second = try await codec.open(secondURL)
        let engine = try await PCMPlaybackEngine(resource: PCMPlaybackResource(format: first.format, session: first.session))
        let next = PlaybackResource(
            providerID: .local,
            transport: .decodedPCM(PCMPlaybackResource(format: second.format, session: second.session))
        )
        #expect(!engine.canPrepare(next))
        await engine.close()
        await second.session.close()
    }

    @Test("Album queue advances once and keeps the second local item")
    func albumQueueAdvances() async throws {
        let firstURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.4)
        let secondURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.4)
        defer {
            try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
        }
        let first = LocalTrack(fileURL: firstURL, title: "First", artist: "Test", album: "Album", duration: 0.4)
        let second = LocalTrack(fileURL: secondURL, title: "Second", artist: "Test", album: "Album", duration: 0.4)
        let playback = PlaybackController()
        playback.play(first, queue: [first, second])
        for _ in 0..<120 where playback.currentTrack?.id != second.id {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(playback.currentTrack?.id == second.id)
        #expect(playback.playbackQueue.history.count == 1)
        #expect(playback.playbackQueue.upcoming.isEmpty)
        #expect(playback.playbackErrorMessage == nil)
        playback.stop()
    }
}
