//
//  SidebarSection.swift
//  MSRU
//

import Foundation


enum SidebarSection:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case listenNow
    case browse
    case radio

    case library
    case importAppleMusic

    case settings


    var id: Self {
        self
    }


    var title: String {
        switch self {

        case .listenNow:
            "Listen Now"

        case .browse:
            "Browse"

        case .radio:
            "Radio"

        case .library:
            "Library"

        case .importAppleMusic:
            "Import Apple Music"

        case .settings:
            "Settings"
        }
    }


    var systemImage: String {
        switch self {

        case .listenNow:
            "play.circle"

        case .browse:
            "sparkles"

        case .radio:
            "dot.radiowaves.left.and.right"

        case .library:
            "music.note.house"

        case .importAppleMusic:
            "square.and.arrow.down"

        case .settings:
            "gear"
        }
    }


    // MARK: - Groups

    static let discoverSections: [SidebarSection] = [
        .listenNow,
        .browse,
        .radio
    ]


    static let librarySections: [SidebarSection] = [
        .library,
        .importAppleMusic,
        .settings
    ]
}
