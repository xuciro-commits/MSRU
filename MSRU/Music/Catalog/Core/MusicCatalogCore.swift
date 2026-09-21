//
//  MusicCatalogCore.swift
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
            String(localized: "Apple Music developer credentials required")
        case .jamendo:
            String(localized: "Jamendo client ID required")
        case .musicBrainz:
            nil
        }
    }
}

enum MusicContentKind:
    String,
    Hashable,
    Codable,
    Sendable {

    case track
    case album
    case artist
    case playlist
}

struct MusicContent:
    Identifiable,
    Hashable,
    Codable,
    Sendable {

    let id: String
    let provider: MusicProviderID
    let kind: MusicContentKind
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let audioURL: URL?
    let externalURL: URL?

    init(
        id: String,
        provider: MusicProviderID,
        kind: MusicContentKind,
        title: String,
        subtitle: String? = nil,
        artworkURL: URL? = nil,
        audioURL: URL? = nil,
        externalURL: URL? = nil
    ) {
        self.id = id
        self.provider = provider
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.audioURL = audioURL
        self.externalURL = externalURL
    }
}

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
    let title: String
    let subtitle: String?
    let layout: MusicSectionLayout
    let items: [MusicContent]

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

protocol MusicCatalogProvider: Sendable {
    var id: MusicProviderID { get }
    func homeSections() async throws -> [MusicSection]
    func search(_ query: String) async throws -> [MusicContent]
}
