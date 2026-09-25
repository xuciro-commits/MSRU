//
//  PlaybackQueueController.swift
//  MSRU
//

import Foundation
import Observation
import MusicDomain
import MusicLibrary

// MARK: - Playback Queue Item

public struct PlaybackQueueItem: Identifiable {
    public let id: UUID
    public let item: PlaybackItem

    public init(id: UUID = UUID(), item: PlaybackItem) {
        self.id = id
        self.item = item
    }
}

// MARK: - Controller

@MainActor
@Observable
public final class PlaybackQueueController {

    public private(set) var history: [PlaybackQueueItem] = []
    public private(set) var current: PlaybackQueueItem?
    public private(set) var upcoming: [PlaybackQueueItem] = []

    public init() {}

    // MARK: - State

    public var canPrevious: Bool {
        !history.isEmpty
    }

    public var canNext: Bool {
        !upcoming.isEmpty
    }

    public var allItems: [PlaybackQueueItem] {
        var result = history
        if let current {
            result.append(current)
        }
        result.append(contentsOf: upcoming)
        return result
    }

    // MARK: - Start

    public func start(_ item: PlaybackItem, context: [PlaybackItem]? = nil) {
        if let context, let index = context.firstIndex(where: { $0.id == item.id }) {
            let queueItems = context.map { PlaybackQueueItem(item: $0) }
            history = Array(queueItems[..<index])
            current = queueItems[index]
            let nextIndex = index + 1
            if nextIndex < queueItems.count {
                upcoming = Array(queueItems[nextIndex...])
            } else {
                upcoming = []
            }
            return
        }

        if current?.item.id != item.id {
            if let current {
                history.append(current)
            }
            current = PlaybackQueueItem(item: item)
        }
    }

    /// Select a queue occurrence, not a media ID (the same song may appear twice).
    @discardableResult
    public func select(id: UUID) -> PlaybackQueueItem? {
        let items = allItems
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        history = Array(items[..<index])
        current = items[index]
        upcoming = Array(items[(index + 1)...])
        return current
    }

    // MARK: - Next

    @discardableResult
    public func advanceNext() -> PlaybackQueueItem? {
        guard !upcoming.isEmpty else { return nil }
        if let current {
            history.append(current)
        }
        let next = upcoming.removeFirst()
        current = next
        return next
    }

    // MARK: - Previous

    @discardableResult
    public func movePrevious() -> PlaybackQueueItem? {
        guard let previous = history.popLast() else { return nil }
        if let current {
            upcoming.insert(current, at: 0)
        }
        current = previous
        return previous
    }

    public func trimHistory(keepingLast count: Int) {
        let excess = history.count - max(0, count)
        if excess > 0 { history.removeFirst(excess) }
    }

    // MARK: - Play Next

    public func playNext(_ item: PlaybackItem) {
        upcoming.removeAll { $0.item.id == item.id }
        upcoming.insert(PlaybackQueueItem(item: item), at: 0)
    }

    // MARK: - Add To Queue

    public func addToQueue(_ item: PlaybackItem) {
        upcoming.append(PlaybackQueueItem(item: item))
    }

    // MARK: - Remove

    public func removeUpcoming(id: UUID) {
        upcoming.removeAll { $0.id == id }
    }

    public func removeUpcoming(at offsets: IndexSet) {
        let indexes = offsets.filter { upcoming.indices.contains($0) }.sorted(by: >)
        for index in indexes {
            upcoming.remove(at: index)
        }
    }

    /// Purges items matching the predicate from upcoming and history. Returns true if the current item was purged.
    @discardableResult
    public func purgeItems(matching: (PlaybackItem) -> Bool) -> Bool {
        upcoming.removeAll { matching($0.item) }
        history.removeAll { matching($0.item) }
        if let cur = current, matching(cur.item) {
            current = nil
            return true
        }
        return false
    }

    // MARK: - Reorder

    public func moveUpcoming(fromOffsets source: IndexSet, toOffset destination: Int) {
        let indexes = source.filter { upcoming.indices.contains($0) }.sorted()
        guard !indexes.isEmpty else { return }

        let movingItems = indexes.map { upcoming[$0] }
        for index in indexes.reversed() {
            upcoming.remove(at: index)
        }

        let removedBeforeDestination = indexes.filter { $0 < destination }.count
        let adjustedDestination = destination - removedBeforeDestination
        let safeDestination = max(0, min(upcoming.count, adjustedDestination))

        upcoming.insert(contentsOf: movingItems, at: safeDestination)
    }

    // MARK: - Clear Upcoming

    public func clearUpcoming() {
        upcoming = []
    }

    // MARK: - Clear History

    public func clearHistory() {
        history = []
    }

    // MARK: - Clear All

    public func clearAll() {
        history = []
        current = nil
        upcoming = []
    }
}
