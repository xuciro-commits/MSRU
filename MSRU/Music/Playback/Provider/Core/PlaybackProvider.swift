//
//  PlaybackProvider.swift
//  MSRU
//

import Foundation


enum PlaybackProviderID:
    String,
    CaseIterable,
    Hashable,
    Sendable {

    case extendedAudio

    case local

    case openverse

    case radio
}


protocol PlaybackProvider:
    Sendable {

    var id:
        PlaybackProviderID {
        get
    }


    var priority:
        Int {
        get
    }


    func canResolve(
        _ request:
            PlaybackRequest
    ) -> Bool


    func resolve(
        _ request:
            PlaybackRequest
    ) async throws
        -> PlaybackResource
}
