//
//  PlaybackRequest.swift
//  MSRU
//

import Foundation


enum PlaybackQuality:
    String,
    Sendable {

    case automatic
    case low
    case standard
    case high
    case lossless
}


struct PlaybackRequest:
    Sendable {

    enum Source:
        String,
        Sendable {

        case local
        case openverse
    }


    let itemID:
        String

    let source:
        Source

    let preferredQuality:
        PlaybackQuality

    let localFileURL:
        URL?

    let remoteURL:
        URL?

    let providerHint:
        PlaybackProviderID?


    // MARK: - Unified Init

    init(
        itemID:
            String,
        source:
            Source,
        preferredQuality:
            PlaybackQuality = .automatic,
        localFileURL:
            URL? = nil,
        remoteURL:
            URL? = nil,
        providerHint:
            PlaybackProviderID? = nil
    ) {

        self.itemID =
            itemID

        self.source =
            source

        self.preferredQuality =
            preferredQuality

        self.localFileURL =
            localFileURL

        self.remoteURL =
            remoteURL

        self.providerHint =
            providerHint
    }


}
