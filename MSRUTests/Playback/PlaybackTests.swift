//
//  PlaybackTests.swift
//  MSRUTests
//
//  Canonical tests for Playback domain and queue invariants.
//

import Foundation
import Testing
@testable import MSRU

@MainActor
@Suite("Playback Invariants")
struct PlaybackTests {

    // MARK: - PlaybackItem Contracts

    @Test("PlaybackItem local metadata and request mapping")
    func playbackItemLocalProperties() {
        let fileURL = URL(fileURLWithPath: "/tmp/sample-track.flac")
        let localTrack = LocalTrack(
            fileURL: fileURL,
            title: "Reckoner",
            artist: "Radiohead",
            album: "In Rainbows",
            duration: 290.0
        )

        let item = PlaybackItem(local: localTrack)

        #expect(item.id == "local:\(fileURL.absoluteString)")
        #expect(item.source == .local)
        #expect(item.title == "Reckoner")
        #expect(item.subtitle == "Radiohead")
        #expect(item.providerLabel == "LOCAL")
        #expect(item.duration == 290.0)
        #expect(item.localTrack?.title == "Reckoner")

        let req = item.playbackRequest
        #expect(req.source == .local)
        #expect(req.localFileURL == fileURL)
        #expect(req.remoteURL == nil)
        #expect(req.providerHint == .local)
    }

    @Test("PlaybackItem Openverse and Radio metadata and request mapping")
    func playbackItemOpenverseAndRadio() {
        let openverse = OpenverseAudio(
            id: "ov-42",
            title: "Creative Commons Groove",
            creator: "Free Artist",
            mediaURLString: "https://example.com/stream.mp3",
            thumbnailURLString: "https://example.com/thumb.jpg",
            durationMilliseconds: 120_000
        )
        let openverseItem = PlaybackItem(openverse: openverse)

        #expect(openverseItem.id == "openverse:ov-42")
        #expect(openverseItem.source == .openverse)
        #expect(openverseItem.title == "Creative Commons Groove")
        #expect(openverseItem.subtitle == "Free Artist")
        #expect(openverseItem.duration == 120.0)
        #expect(openverseItem.playbackRequest.remoteURL == URL(string: "https://example.com/stream.mp3"))

        let radio = RadioStation(
            id: "kexp-seattle",
            name: "KEXP 90.3 FM",
            description: "Listener powered music",
            genre: .indie,
            streamURL: URL(string: "https://live.kexp.org/kexp128.mp3")!,
            homepageURL: nil,
            artworkURL: nil,
            country: "USA",
            language: "English"
        )
        let radioItem = PlaybackItem(radio: radio)

        #expect(radioItem.id == "radio:kexp-seattle")
        #expect(radioItem.source == .radio)
        #expect(radioItem.title == "KEXP 90.3 FM")
        #expect(radioItem.subtitle == "Indie & Alternative • USA")
        #expect(radioItem.duration == nil)
        #expect(radioItem.playbackRequest.remoteURL == URL(string: "https://live.kexp.org/kexp128.mp3"))
    }

    @Test("PlaybackItem initializes from LibraryTrack with source precedence")
    func playbackItemLibraryPrecedence() {
        let fileURL = URL(fileURLWithPath: "/tmp/local-version.m4a")
        let localSource = LibraryPlaybackSource(kind: .local, localFileURL: fileURL)
        let openverseSource = LibraryPlaybackSource(kind: .openverse, externalID: "ov-99", remoteURL: URL(string: "https://example.com/ov.mp3"))

        // 1. Both sources present: Local takes priority
        let multiSourceTrack = LibraryTrack(
            id: UUID(),
            title: "Multi Source Song",
            artist: "Artist",
            album: "Album",
            duration: 200,
            sources: [localSource, openverseSource]
        )
        let item1 = PlaybackItem(library: multiSourceTrack)
        #expect(item1 != nil)
        #expect(item1?.source == .local)

        // 2. Only Openverse source present
        let remoteOnlyTrack = LibraryTrack(
            id: UUID(),
            title: "Remote Song",
            artist: "Artist",
            album: "Album",
            duration: 180,
            sources: [openverseSource]
        )
        let item2 = PlaybackItem(library: remoteOnlyTrack)
        #expect(item2 != nil)
        #expect(item2?.source == .openverse)

        // 3. Only unsupported future source present -> returns nil
        let unsupportedTrack = LibraryTrack(
            id: UUID(),
            title: "Future Song",
            artist: "Artist",
            album: "Album",
            sources: [LibraryPlaybackSource(kind: .jamendo, remoteURL: URL(string: "https://jamendo.com/123"))]
        )
        let item3 = PlaybackItem(library: unsupportedTrack)
        #expect(item3 == nil)
    }

    // MARK: - PlaybackQueueController Invariants

    private func makeItem(_ id: String, title: String) -> PlaybackItem {
        PlaybackItem(local: LocalTrack(
            fileURL: URL(fileURLWithPath: "/tmp/\(id).flac"),
            title: title,
            artist: "Artist",
            album: "Album",
            duration: 180
        ))
    }

    @Test("Queue initializes correctly with context splitting history, current, and upcoming")
    func queueStartWithContext() {
        let controller = PlaybackQueueController()
        let items = (1...4).map { makeItem("song-\($0)", title: "Song \($0)") }

        // Start playing song 3 in context of [song 1, 2, 3, 4]
        controller.start(items[2], context: items)

        #expect(controller.current?.item.id == items[2].id)
        #expect(controller.history.map(\.item.id) == [items[0].id, items[1].id])
        #expect(controller.upcoming.map(\.item.id) == [items[3].id])
        #expect(controller.canPrevious == true)
        #expect(controller.canNext == true)
        #expect(controller.allItems.count == 4)
    }

    @Test("Queue advancing and retreating updates history and upcoming deterministically")
    func queueAdvanceAndMovePrevious() {
        let controller = PlaybackQueueController()
        let items = (1...3).map { makeItem("track-\($0)", title: "Track \($0)") }

        controller.start(items[0], context: items)

        #expect(controller.canPrevious == false)
        #expect(controller.canNext == true)

        // Advance to track 2
        let next1 = controller.advanceNext()
        #expect(next1?.item.id == items[1].id)
        #expect(controller.current?.item.id == items[1].id)
        #expect(controller.history.count == 1)
        #expect(controller.upcoming.count == 1)
        #expect(controller.canPrevious == true)
        #expect(controller.canNext == true)

        // Advance to track 3 (end of queue)
        let next2 = controller.advanceNext()
        #expect(next2?.item.id == items[2].id)
        #expect(controller.canNext == false)

        // Attempt to advance past end returns nil
        #expect(controller.advanceNext() == nil)

        // Move previous back to track 2
        let prev1 = controller.movePrevious()
        #expect(prev1?.item.id == items[1].id)
        #expect(controller.current?.item.id == items[1].id)
        #expect(controller.upcoming.count == 1)
        #expect(controller.upcoming.first?.item.id == items[2].id)

        // Move previous back to track 1
        let prev2 = controller.movePrevious()
        #expect(prev2?.item.id == items[0].id)
        #expect(controller.canPrevious == false)
        #expect(controller.movePrevious() == nil)
    }

    @Test("Paged playback history remains bounded")
    func queueHistoryTrim() {
        let controller = PlaybackQueueController()
        let items = (0..<300).map { makeItem("paged-\($0)", title: "Song \($0)") }
        controller.start(items[0], context: items)
        for _ in 1..<300 {
            _ = controller.advanceNext()
            controller.trimHistory(keepingLast: 256)
        }
        #expect(controller.history.count == 256)
        #expect(controller.current?.item.id == items[299].id)
        #expect(controller.history.first?.item.id == items[43].id)
    }

    @Test("PlayNext moves existing upcoming item to front or inserts new item")
    func queuePlayNextDeduplication() {
        let controller = PlaybackQueueController()
        let itemA = makeItem("a", title: "A")
        let itemB = makeItem("b", title: "B")
        let itemC = makeItem("c", title: "C")
        let itemD = makeItem("d", title: "D")

        controller.start(itemA, context: [itemA, itemB, itemC])
        #expect(controller.upcoming.map(\.item.id) == [itemB.id, itemC.id])

        // Play item C next: should remove C from its position and place at front
        controller.playNext(itemC)
        #expect(controller.upcoming.map(\.item.id) == [itemC.id, itemB.id])

        // Play brand new item D next: inserted at index 0
        controller.playNext(itemD)
        #expect(controller.upcoming.map(\.item.id) == [itemD.id, itemC.id, itemB.id])
    }

    @Test("Queue reorder and removal maintains consistent order")
    func queueReorderAndRemoval() {
        let controller = PlaybackQueueController()
        let items = (1...4).map { makeItem("reorder-\($0)", title: "Item \($0)") }

        controller.start(items[0], context: items)
        #expect(controller.upcoming.count == 3)

        // Remove upcoming by index
        controller.removeUpcoming(at: IndexSet(integer: 1)) // removes items[2]
        #expect(controller.upcoming.map(\.item.id) == [items[1].id, items[3].id])

        // Add to queue appends at end
        let item5 = makeItem("reorder-5", title: "Item 5")
        controller.addToQueue(item5)
        #expect(controller.upcoming.map(\.item.id) == [items[1].id, items[3].id, item5.id])

        // Move items[1] from index 0 to index 2
        controller.moveUpcoming(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(controller.upcoming.map(\.item.id) == [items[3].id, items[1].id, item5.id])
    }

    @Test("Clear operations reset queue state safely")
    func queueClearOperations() {
        let controller = PlaybackQueueController()
        let items = (1...3).map { makeItem("clear-\($0)", title: "Clear \($0)") }

        controller.start(items[1], context: items)
        #expect(controller.history.count == 1)
        #expect(controller.current != nil)
        #expect(controller.upcoming.count == 1)

        controller.clearUpcoming()
        #expect(controller.upcoming.isEmpty)
        #expect(controller.current != nil)

        controller.clearHistory()
        #expect(controller.history.isEmpty)
        #expect(controller.canPrevious == false)

        controller.clearAll()
        #expect(controller.history.isEmpty)
        #expect(controller.current == nil)
        #expect(controller.upcoming.isEmpty)
        #expect(controller.allItems.isEmpty)
    }
}
