import Foundation
import Testing
@testable import MSRU

@MainActor
struct PlaybackQueueTests {
    @Test
    func selectingDuplicateOccurrenceKeepsMixedQueueAndStableIDs() {
        let queue = PlaybackQueueController()
        let local = PlaybackItem(local: MSRUPreviewData.localTracks[0])
        let remote = PlaybackItem(openverse: MSRUPreviewData.openverseOne)
        queue.start(local, context: [local, remote, local, remote])
        let original = queue.allItems.map(\.id)
        let duplicate = queue.upcoming[1]
        let selected = queue.select(id: duplicate.id)
        #expect(selected?.id == duplicate.id)
        #expect(queue.history.map(\.item.id) == [local.id, remote.id])
        #expect(queue.upcoming.map(\.item.id) == [remote.id])
        #expect(queue.allItems.map(\.id) == original)
        #expect(queue.movePrevious()?.item.id == remote.id)
        #expect(queue.advanceNext()?.id == duplicate.id)
    }

    @Test
    func missingQueueSelectionLeavesStateUnchanged() {
        let queue = PlaybackQueueController()
        let item = PlaybackItem(local: MSRUPreviewData.localTracks[0])
        queue.start(item)
        queue.addToQueue(item)
        let original = queue.allItems.map(\.id)
        let selected = queue.select(id: UUID())
        #expect(selected == nil)
        #expect(queue.allItems.map(\.id) == original)
        #expect(queue.history.isEmpty)
    }
}

@MainActor
private final class FailingPCMDecodeSession: PCMDecodeSession {
    private(set) var isClosed = false
    func read(maxFrames: Int) async throws -> PCMFrameBlock? {
        throw NSError(domain: "PCMFixture", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Fixture PCM decode failed"])
    }
    func seek(to seconds: TimeInterval) async throws {}
    func close() async { isClosed = true }
}

@MainActor
private final class FailingPCMProvider: PlaybackProvider {
    nonisolated let id: PlaybackProviderID = .extendedAudio
    nonisolated let priority = 1
    private(set) var sessions: [FailingPCMDecodeSession] = []
    nonisolated func canResolve(_ request: PlaybackRequest) -> Bool { true }
    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        let session = FailingPCMDecodeSession()
        sessions.append(session)
        return PlaybackResource(providerID: id, transport: .decodedPCM(.init(
            format: .init(sampleRate: 44_100, channels: 2, duration: 1), session: session)))
    }
}

extension AudioHardwareTestSuite {
    @Suite(.serialized)
    @MainActor
    struct PCMPlaybackFailureTests {
        @Test
        func decodeFailureClosesSessionAndRetryCreatesFreshTransport() async throws {
            let provider = FailingPCMProvider()
            let registry = ProviderRegistry()
            registry.register(provider)
            let controller = PlaybackController(providerKernel: .init(registry: registry))
            controller.play(MSRUPreviewData.localTracks[0])
            let queueIDs = controller.playbackQueue.allItems.map(\.id)
            for attempt in 1...2 {
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                while controller.playbackErrorMessage == nil && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(10))
                }
                #expect(controller.playbackErrorMessage == "Fixture PCM decode failed")
                #expect(!controller.isPlaying)
                #expect(!controller.isResolving)
                #expect(controller.currentResource == nil)
                let sessions = provider.sessions
                #expect(sessions.count == attempt)
                let session = try #require(sessions.last)
                while !session.isClosed && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(10))
                }
                #expect(session.isClosed)
                #expect(controller.playbackQueue.allItems.map(\.id) == queueIDs)
                if attempt == 1 {
                    controller.retryLastFailedResolution()
                    #expect(controller.playbackErrorMessage == nil)
                }
            }
        }
    }
}
