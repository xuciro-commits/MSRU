//
//  MusicCatalogCore.swift
//  MSRU
//

import Foundation
import MusicDomain

public enum MusicProviderID: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case appleMusic
    case musicBrainz

    public var id: Self { self }

    // MARK: - Display

    public var title: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .musicBrainz: "MusicBrainz"
        }
    }

    public var systemImage: String {
        switch self {
        case .appleMusic: "apple.logo"
        case .musicBrainz: "music.note.list"
        }
    }

    // MARK: - Availability

    public var isAvailable: Bool {
        true
    }

    public var availabilityDescription: String? {
        nil
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
