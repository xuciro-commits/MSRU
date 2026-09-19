//
//  LibraryPlaybackSource.swift
//  MSRU
//

import Foundation


enum LibraryPlaybackSourceKind:
    String,
    Codable,
    Hashable,
    Sendable {

    case local
    case openverse

    // Future
    case jamendo
    case appleMusic
    case openSubsonic
}


struct LibraryPlaybackSource:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    let id:
        UUID

    let kind:
        LibraryPlaybackSourceKind

    let externalID:
        String?

    let localFileURL:
        URL?

    let remoteURL:
        URL?


    init(
        id: UUID = UUID(),
        kind: LibraryPlaybackSourceKind,
        externalID: String? = nil,
        localFileURL: URL? = nil,
        remoteURL: URL? = nil
    ) {

        self.id =
            id

        self.kind =
            kind

        self.externalID =
            externalID

        self.localFileURL =
            localFileURL

        self.remoteURL =
            remoteURL
    }
}
