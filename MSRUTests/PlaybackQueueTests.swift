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
