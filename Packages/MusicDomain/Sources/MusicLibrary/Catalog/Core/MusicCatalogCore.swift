//
//  MusicCatalogCore.swift
//  MSRU
//

import Foundation
import MusicDomain

public enum MusicProviderID: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case appleMusic
    case jamendo
    case musicBrainz

    public var id: Self { self }

    // MARK: - Display

    public var title: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .jamendo: "Jamendo"
        case .musicBrainz: "MusicBrainz"
        }
    }

    public var systemImage: String {
        switch self {
        case .appleMusic: "music.note"
        case .jamendo: "waveform"
        case .musicBrainz: "music.note.list"
        }
    }

    // MARK: - Availability

    public var isAvailable: Bool {
        switch self {
        case .musicBrainz: true
        case .appleMusic, .jamendo: false
        }
    }

    public var availabilityDescription: String? {
        switch self {
        case .appleMusic: String(localized: "Apple Music developer credentials required")
        case .jamendo: String(localized: "Jamendo client ID required")
        case .musicBrainz: nil
        }
    }
}

public enum MusicContentKind: String, Hashable, Codable, Sendable {
    case track
    case album
    case artist
    case playlist
}

public struct MusicContent: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let provider: MusicProviderID
    public let kind: MusicContentKind
    public let title: String
    public let subtitle: String?
    public let artworkURL: URL?
    public let audioURL: URL?
    public let externalURL: URL?

    public init(
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
