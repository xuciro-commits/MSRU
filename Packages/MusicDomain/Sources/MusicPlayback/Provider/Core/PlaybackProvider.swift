//
//  PlaybackProvider.swift
//  MSRU
//

import Foundation
import MusicDomain
import MusicLibrary

// MARK: - Playback Provider ID & Protocol

public enum PlaybackProviderID: String, CaseIterable, Hashable, Sendable {
    case extendedAudio
    case local
    case openverse
    case radio
    case subsonic
}

public protocol PlaybackProvider: Sendable {
    var id: PlaybackProviderID { get }
    var priority: Int { get }

    func canResolve(_ request: PlaybackRequest) -> Bool
    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource
}

// MARK: - Playback Request

public enum PlaybackQuality: String, Sendable {
    case automatic
    case low
    case standard
    case high
    case lossless
}

public struct PlaybackRequest: Sendable {

    public enum Source: String, Sendable {
        case local
        case openverse
        case radio
        case subsonic
    }

    public let itemID: String
    public let source: Source
    public let preferredQuality: PlaybackQuality
    public let localFileURL: URL?
    public let remoteURL: URL?
    public let subsonicServerID: String?
    public let prefersPreparedPCM: Bool
    public let providerHint: PlaybackProviderID?

    public init(
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

    public func preparingPCM() -> PlaybackRequest {
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

public struct PCMPlaybackResource: Sendable {
    public let format: PCMStreamFormat
    public let session: any PCMDecodeSession

    public init(format: PCMStreamFormat, session: any PCMDecodeSession) {
        self.format = format
        self.session = session
    }
}

public enum PlaybackTransport: Sendable {
    case avPlayerURL(URL)
    case decodedPCM(PCMPlaybackResource)
    case providerNative(providerID: PlaybackProviderID, token: String?)
}

public struct PlaybackResource: Sendable {

    public let providerID: PlaybackProviderID
    public let transport: PlaybackTransport
    public let duration: TimeInterval?
    public let expiresAt: Date?

    public init(
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

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}
