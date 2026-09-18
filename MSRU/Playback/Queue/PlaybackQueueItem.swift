//
//  PlaybackQueueItem.swift
//  MSRU
//

import Foundation


struct PlaybackQueueItem:
    Identifiable {

    let id:
        UUID

    let item:
        PlaybackItem


    init(
        id: UUID = UUID(),
        item: PlaybackItem
    ) {

        self.id =
            id

        self.item =
            item
    }
}
