//
//  MusicSection.swift
//  MSRU
//

import Foundation


enum MusicSectionLayout:
    String,
    Hashable,
    Codable,
    Sendable {

    case featured
    case shelf
    case compactShelf
    case grid
}


struct MusicSection:
    Identifiable,
    Hashable,
    Codable,
    Sendable {

    let id: String

    let title:
        String

    let subtitle:
        String?

    let layout:
        MusicSectionLayout

    let items:
        [MusicContent]


    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        layout: MusicSectionLayout,
        items: [MusicContent]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
        self.items = items
    }
}
