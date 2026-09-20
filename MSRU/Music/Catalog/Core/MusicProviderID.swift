//
//  MusicProviderID.swift
//  MSRU
//

import Foundation


enum MusicProviderID:
    String,
    CaseIterable,
    Identifiable,
    Hashable,
    Codable,
    Sendable {

    case appleMusic
    case jamendo
    case musicBrainz


    var id: Self {
        self
    }


    // MARK: - Display

    var title: String {
        switch self {

        case .appleMusic:
            "Apple Music"

        case .jamendo:
            "Jamendo"

        case .musicBrainz:
            "MusicBrainz"
        }
    }


    var systemImage: String {
        switch self {

        case .appleMusic:
            "music.note"

        case .jamendo:
            "waveform"

        case .musicBrainz:
            "music.note.list"
        }
    }


    // MARK: - Availability

    var isAvailable: Bool {
        switch self {

        case .musicBrainz:
            true

        case .appleMusic,
             .jamendo:
            false
        }
    }


    var availabilityDescription: String? {
        switch self {

        case .appleMusic:
            "需要 Apple Music 开发者权限"

        case .jamendo:
            "需要 Jamendo 客户端 ID"

        case .musicBrainz:
            nil
        }
    }
}
