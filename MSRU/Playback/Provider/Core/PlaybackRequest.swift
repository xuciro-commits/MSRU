//
//  PlaybackRequest.swift
//  MSRU
//

import Foundation


struct PlaybackRequest:
    Sendable {

    // MARK: - Request Identity

    let requestID:
        UUID


    // MARK: - Track Identity

    let trackID:
        String


    // MARK: - Preferences

    let preferredQuality:
        PlaybackQuality

    let preferredProviderID:
        PlaybackProviderID?


    // MARK: - Source Hints

    let localFileURL:
        URL?


    init(
        requestID:
            UUID = UUID(),
        trackID:
            String,
        preferredQuality:
            PlaybackQuality = .automatic,
        preferredProviderID:
            PlaybackProviderID? = nil,
        localFileURL:
            URL? = nil
    ) {

        self.requestID =
            requestID

        self.trackID =
            trackID

        self.preferredQuality =
            preferredQuality

        self.preferredProviderID =
            preferredProviderID

        self.localFileURL =
            localFileURL
    }
}
