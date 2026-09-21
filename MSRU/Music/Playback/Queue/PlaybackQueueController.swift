//
//  PlaybackQueueController.swift
//  MSRU
//

import Foundation
import Observation

// MARK: - Playback Queue Item

struct PlaybackQueueItem: Identifiable {
    let id: UUID
    let item: PlaybackItem

    init(id: UUID = UUID(), item: PlaybackItem) {
        self.id = id
        self.item = item
    }
}

// MARK: - Controller

@MainActor
@Observable
final class PlaybackQueueController {


    private(set) var history:
        [PlaybackQueueItem] = []

    private(set) var current:
        PlaybackQueueItem?

    private(set) var upcoming:
        [PlaybackQueueItem] = []


    // MARK: - State

    var canPrevious:
        Bool {

        !history.isEmpty
    }


    var canNext:
        Bool {

        !upcoming.isEmpty
    }


    var allItems:
        [PlaybackQueueItem] {

        var result =
            history


        if let current {

            result.append(
                current
            )
        }


        result.append(
            contentsOf:
                upcoming
        )


        return result
    }


    // MARK: - Start

    func start(
        _ item:
            PlaybackItem,
        context:
            [PlaybackItem]? = nil
    ) {

        /*
         有完整播放上下文。

         例如：

         Album
         Library
         Search Results

         直接建立：

         history
         current
         upcoming
         */
        if let context,
           let index =
                context.firstIndex(
                    where: {
                        $0.id == item.id
                    }
                ) {

            let queueItems:
                [PlaybackQueueItem] =
                context.map {
                    PlaybackQueueItem(
                        item:
                            $0
                    )
                }


            history =
                Array(
                    queueItems[
                        ..<index
                    ]
                )


            current =
                queueItems[
                    index
                ]


            let nextIndex =
                index + 1


            if nextIndex
                < queueItems.count {

                upcoming =
                    Array(
                        queueItems[
                            nextIndex...
                        ]
                    )

            } else {

                upcoming =
                    []
            }


            return
        }


        /*
         Play Now。

         如果是另一首歌曲：

         old current -> history
         new item    -> current

         原来的 upcoming 保留。
         */
        if current?
            .item
            .id
            != item.id {

            if let current {

                history.append(
                    current
                )
            }


            current =
                PlaybackQueueItem(
                    item:
                        item
                )
        }
    }


    /// Select a queue occurrence, not a media ID (the same song may appear twice).
    @discardableResult
    func select(id: UUID) -> PlaybackQueueItem? {
        let items = allItems
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        history = Array(items[..<index])
        current = items[index]
        upcoming = Array(items[(index + 1)...])
        return current
    }

    // MARK: - Next

    @discardableResult
    func advanceNext()
        -> PlaybackQueueItem? {

        guard
            !upcoming.isEmpty
        else {
            return nil
        }


        if let current {

            history.append(
                current
            )
        }


        let next =
            upcoming.removeFirst()


        current =
            next


        return next
    }


    // MARK: - Previous

    @discardableResult
    func movePrevious()
        -> PlaybackQueueItem? {

        guard
            let previous =
                history.popLast()
        else {
            return nil
        }


        if let current {

            upcoming.insert(
                current,
                at:
                    0
            )
        }


        current =
            previous


        return previous
    }


    // MARK: - Play Next

    func playNext(
        _ item:
            PlaybackItem
    ) {

        /*
         同一歌曲如果已经位于 upcoming，
         先移除，再插到首位。
         */
        upcoming.removeAll {
            queueItem in

            queueItem.item.id
                == item.id
        }


        upcoming.insert(
            PlaybackQueueItem(
                item:
                    item
            ),
            at:
                0
        )
    }


    // MARK: - Add To Queue

    func addToQueue(
        _ item:
            PlaybackItem
    ) {

        upcoming.append(
            PlaybackQueueItem(
                item:
                    item
            )
        )
    }


    // MARK: - Remove

    func removeUpcoming(
        id:
            UUID
    ) {

        upcoming.removeAll {
            queueItem in

            queueItem.id
                == id
        }
    }


    func removeUpcoming(
        at offsets:
            IndexSet
    ) {

        /*
         倒序删除，
         防止删除前面的元素后 index 发生移动。
         */
        let indexes =
            offsets
                .filter {
                    upcoming.indices
                        .contains(
                            $0
                        )
                }
                .sorted(
                    by:
                        >
                )


        for index
            in indexes {

            upcoming.remove(
                at:
                    index
            )
        }
    }


    // MARK: - Reorder

    func moveUpcoming(
        fromOffsets source:
            IndexSet,
        toOffset destination:
            Int
    ) {

        /*
         SwiftUI List 的 move：

         1. 提取合法 index
         2. 保存待移动元素
         3. 从后往前删除
         4. 修正 destination
         5. 插入

         不使用 compactMap，
         避免 Swift 6.x 在这里出现
         ElementOfResult 推断失败。
         */
        let indexes:
            [Int] =
            source
                .filter {
                    upcoming.indices
                        .contains(
                            $0
                        )
                }
                .sorted()


        guard
            !indexes.isEmpty
        else {
            return
        }


        let movingItems:
            [PlaybackQueueItem] =
            indexes.map {
                index in

                upcoming[
                    index
                ]
            }


        for index
            in indexes.reversed() {

            upcoming.remove(
                at:
                    index
            )
        }


        let removedBeforeDestination =
            indexes
                .filter {
                    $0 < destination
                }
                .count


        let adjustedDestination =
            destination
            - removedBeforeDestination


        let safeDestination =
            max(
                0,
                min(
                    upcoming.count,
                    adjustedDestination
                )
            )


        upcoming.insert(
            contentsOf:
                movingItems,
            at:
                safeDestination
        )
    }


    // MARK: - Clear Upcoming

    func clearUpcoming() {

        upcoming =
            []
    }


    // MARK: - Clear History

    func clearHistory() {

        history =
            []
    }


    // MARK: - Clear All

    func clearAll() {

        history =
            []

        current =
            nil

        upcoming =
            []
    }
}
