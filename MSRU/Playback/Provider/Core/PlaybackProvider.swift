//
//  PlaybackProvider.swift
//  MSRU
//

import Foundation


// MARK: - Provider ID

nonisolated struct PlaybackProviderID:
    RawRepresentable,
    Hashable,
    Codable,
    Sendable,
    CustomStringConvertible {

    let rawValue:
        String


    init(
        rawValue: String
    ) {

        self.rawValue =
            rawValue
    }


    var description:
        String {

        rawValue
    }
}


// MARK: - Built-in Provider IDs

nonisolated extension PlaybackProviderID {

    static let local =
        PlaybackProviderID(
            rawValue:
                "local"
        )
}


// MARK: - Quality

nonisolated enum PlaybackQuality:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable {

    case automatic

    case low

    case standard

    case high

    case lossless

    case original
}


// MARK: - Capabilities

nonisolated struct PlaybackProviderCapabilities:
    OptionSet,
    Hashable,
    Sendable {

    let rawValue:
        Int


    init(
        rawValue: Int
    ) {

        self.rawValue =
            rawValue
    }


    static let playback =
        Self(
            rawValue:
                1 << 0
        )


    static let localFile =
        Self(
            rawValue:
                1 << 1
        )


    static let remoteURL =
        Self(
            rawValue:
                1 << 2
        )


    static let nativePlayback =
        Self(
            rawValue:
                1 << 3
        )


    static let qualitySelection =
        Self(
            rawValue:
                1 << 4
        )


    static let download =
        Self(
            rawValue:
                1 << 5
        )
}


// MARK: - Descriptor

nonisolated struct PlaybackProviderDescriptor:
    Hashable,
    Sendable {

    let id:
        PlaybackProviderID

    let displayName:
        String

    let capabilities:
        PlaybackProviderCapabilities

    let supportedQualities:
        Set<PlaybackQuality>
}


// MARK: - Provider Protocol

nonisolated protocol PlaybackProvider:
    Sendable {

    var descriptor:
        PlaybackProviderDescriptor {
        get
    }


    func healthCheck()
        async
        -> ProviderHealth


    func canResolve(
        _ request:
            PlaybackRequest
    ) async -> Bool


    func resolve(
        _ request:
            PlaybackRequest
    ) async throws
        -> PlaybackResource
}


// MARK: - Defaults

nonisolated extension PlaybackProvider {

    func healthCheck()
        async
        -> ProviderHealth {

        await .available
    }
}
