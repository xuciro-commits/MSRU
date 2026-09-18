//
//  PlaybackResource.swift
//  MSRU
//

import Foundation


enum PlaybackTransport:
    Sendable {

    case avPlayerURL(
        URL
    )

    case providerNative(
        providerID:
            PlaybackProviderID,
        token:
            String?
    )
}


struct PlaybackResource:
    Sendable {

    let providerID:
        PlaybackProviderID

    let transport:
        PlaybackTransport

    let duration:
        TimeInterval?

    let expiresAt:
        Date?


    init(
        providerID:
            PlaybackProviderID,
        transport:
            PlaybackTransport,
        duration:
            TimeInterval? = nil,
        expiresAt:
            Date? = nil
    ) {

        self.providerID =
            providerID

        self.transport =
            transport

        self.duration =
            duration

        self.expiresAt =
            expiresAt
    }


    var isExpired:
        Bool {

        guard let expiresAt
        else {
            return false
        }


        return expiresAt
            <= Date()
    }
}
