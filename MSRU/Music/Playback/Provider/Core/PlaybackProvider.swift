//
//  PlaybackProvider.swift
//  MSRU
//

import Foundation

// MARK: - Playback Provider ID & Protocol

enum PlaybackProviderID: String, CaseIterable, Hashable, Sendable {
    case extendedAudio
    case local
    case openverse
    case radio
    case subsonic
}

protocol PlaybackProvider: Sendable {
    var id: PlaybackProviderID { get }
    var priority: Int { get }

    func canResolve(_ request: PlaybackRequest) -> Bool
    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource
}

// MARK: - Playback Request

enum PlaybackQuality: String, Sendable {
    case automatic
    case low
    case standard
    case high
    case lossless
}

struct PlaybackRequest: Sendable {

    enum Source: String, Sendable {
        case local
        case openverse
        case radio
        case subsonic
    }

    let itemID: String
    let source: Source
    let preferredQuality: PlaybackQuality
    let localFileURL: URL?
    let remoteURL: URL?
    let subsonicServerID: String?
    let prefersPreparedPCM: Bool
    let providerHint: PlaybackProviderID?

    init(
        itemID: String,
        source: Source,
        preferredQuality: PlaybackQuality = .automatic,
        localFileURL: URL? = nil,
        remoteURL: URL? = nil,
        subsonicServerID: String? = nil,
        prefersPreparedPCM: Bool = false,
        providerHint: PlaybackProviderID? = nil
    ) {
        self.itemID = itemID
        self.source = source
        self.preferredQuality = preferredQuality
        self.localFileURL = localFileURL
        self.remoteURL = remoteURL
        self.subsonicServerID = subsonicServerID
        self.prefersPreparedPCM = prefersPreparedPCM
        self.providerHint = providerHint
    }

    func preparingPCM() -> PlaybackRequest {
        PlaybackRequest(
            itemID: itemID,
            source: source,
            preferredQuality: preferredQuality,
            localFileURL: localFileURL,
            remoteURL: remoteURL,
            subsonicServerID: subsonicServerID,
            prefersPreparedPCM: true,
            providerHint: providerHint
        )
    }
}

// MARK: - Playback Resource

struct PCMPlaybackResource: Sendable {
    let format: PCMStreamFormat
    let session: any PCMDecodeSession
}

enum PlaybackTransport: Sendable {
    case avPlayerURL(URL)
    case decodedPCM(PCMPlaybackResource)
    case providerNative(providerID: PlaybackProviderID, token: String?)
}

struct PlaybackResource: Sendable {

    let providerID: PlaybackProviderID
    let transport: PlaybackTransport
    let duration: TimeInterval?
    let expiresAt: Date?

    init(
        providerID: PlaybackProviderID,
        transport: PlaybackTransport,
        duration: TimeInterval? = nil,
        expiresAt: Date? = nil
    ) {
        self.providerID = providerID
        self.transport = transport
        self.duration = duration
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}
