//
//  SceneSection+Sidebar.swift
//  MSRU
//

import Foundation


// MARK: - Sidebar Presentation

/*
 SceneSection 本身只表达语义。

 这里才定义它在当前 Sidebar UI 中
 如何被展示和分组。
 */

@MainActor
extension SceneSection {

    var title:
        String {

        switch self {

        case .listenNow:
            "Listen Now"

        case .browse:
            "Browse"

        case .radio:
            "Radio"

        case .library:
            "Library"

        case .addMusic:
            "Add Music"

        case .settings:
            "Settings"
        }
    }


    var systemImage:
        String {

        switch self {

        case .listenNow:
            "play.circle"

        case .browse:
            "sparkles"

        case .radio:
            "dot.radiowaves.left.and.right"

        case .library:
            "music.note.house"

        case .addMusic:
            "plus.square.on.square"

        case .settings:
            "gearshape"
        }
    }


    static let discoverSections:
        [SceneSection] = [

            .listenNow,
            .browse,
            .radio
        ]


    static let librarySections:
        [SceneSection] = [

            .library,
            .addMusic
        ]
}
