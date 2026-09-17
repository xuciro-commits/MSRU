//
//  MusicContent.swift
//  MSRU
//

import Foundation


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

    let provider:
        MusicProviderID

    let kind:
        MusicContentKind

    let title:
        String

    let subtitle:
        String?

    let artworkURL:
        URL?

    let audioURL:
        URL?

    let externalURL:
        URL?


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
