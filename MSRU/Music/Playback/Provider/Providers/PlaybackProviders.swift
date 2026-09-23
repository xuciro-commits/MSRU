//
//  PlaybackProviders.swift
//  MSRU
//

import Foundation
import MediaLibrary
import SubsonicKit

// MARK: - Local Playback Provider

struct LocalPlaybackProvider: PlaybackProvider {

    let id: PlaybackProviderID = .local
    let priority = 1_000
    private let codec = AppleAudioFileDecoder()

    func canResolve(_ request: PlaybackRequest) -> Bool {
        guard request.source == .local, let url = request.localFileURL else {
            return false
        }
        guard !ExtendedAudioFormatSupport.supports(url) else {
            return false
        }
        return true
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        guard let url = request.localFileURL else {
            throw LocalPlaybackProviderError.missingFileURL
        }
        guard url.isFileURL else {
            throw LocalPlaybackProviderError.invalidFileURL
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalPlaybackProviderError.fileNotFound(url)
        }

        do {
            let decoded = try await codec.open(url)
            return PlaybackResource(
                providerID: .local,
                transport: .decodedPCM(PCMPlaybackResource(format: decoded.format, session: decoded.session)),
                duration: decoded.format.duration
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Keep AVPlayer support for local formats AVAudioFile cannot decode.
            return PlaybackResource(providerID: .local, transport: .avPlayerURL(url))
        }
    }
}

private enum LocalPlaybackProviderError: LocalizedError {
    case missingFileURL
    case invalidFileURL
    case fileNotFound(URL)

    var errorDescription: String? {
        switch self {
        case .missingFileURL:
            return "The local track has no file URL."
        case .invalidFileURL:
            return "The local playback URL is not a file URL."
        case .fileNotFound(let url):
            return "Local audio file was not found: \(url.lastPathComponent)"
        }
    }
}

// MARK: - Extended Audio Playback Provider

struct ExtendedAudioPlaybackProvider: PlaybackProvider {

    let id: PlaybackProviderID = .extendedAudio
    let priority = 2_000

    private let codec: any AudioCodecBackend

    init(codec: any AudioCodecBackend = FFmpegCodecBackend()) {
        self.codec = codec
    }

    func canResolve(_ request: PlaybackRequest) -> Bool {
        guard request.source == .local, let url = request.localFileURL else {
            return false
        }
        return codec.canDecode(url)
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        guard let url = request.localFileURL else {
            throw ExtendedAudioPlaybackError.missingFile
        }

        let decoded = try await codec.open(url)

        return PlaybackResource(
            providerID: .extendedAudio,
            transport: .decodedPCM(
                PCMPlaybackResource(
                    format: decoded.format,
                    session: decoded.session
                )
            ),
            duration: decoded.format.duration
        )
    }
}

private enum ExtendedAudioPlaybackError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        "Extended audio source file is missing."
    }
}

// MARK: - Openverse Playback Provider

struct OpenversePlaybackProvider: PlaybackProvider {

    let id: PlaybackProviderID = .openverse
    let priority = 900

    func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .openverse && request.remoteURL != nil
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        guard let url = request.remoteURL else {
            throw OpenversePlaybackProviderError.missingURL
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw OpenversePlaybackProviderError.invalidURL
        }

        return PlaybackResource(
            providerID: .openverse,
            transport: .avPlayerURL(url)
        )
    }
}

private enum OpenversePlaybackProviderError: LocalizedError {
    case missingURL
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Openverse returned no playable audio URL."
        case .invalidURL:
            return "Openverse returned an invalid audio URL."
        }
    }
}

// MARK: - Radio Playback Provider

struct RadioPlaybackProvider: PlaybackProvider {

    let id: PlaybackProviderID = .radio
    let priority = 850

    func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .radio && request.remoteURL != nil
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        guard let url = request.remoteURL else {
            throw RadioPlaybackProviderError.missingStreamURL
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw RadioPlaybackProviderError.invalidStreamURL
        }

        return PlaybackResource(
            providerID: .radio,
            transport: .avPlayerURL(url)
        )
    }
}

private enum RadioPlaybackProviderError: LocalizedError {
    case missingStreamURL
    case invalidStreamURL

    var errorDescription: String? {
        switch self {
        case .missingStreamURL:
            return "Radio station has no valid stream URL."
        case .invalidStreamURL:
            return "Radio station stream URL must use http or https scheme."
        }
    }
}

// MARK: - Remote Subsonic Playback Provider

struct RemoteSubsonicPlaybackProvider: PlaybackProvider {

    let id: PlaybackProviderID = .subsonic
    let priority = 950

    func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .subsonic && (request.remoteURL != nil || !request.itemID.isEmpty)
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        if let url = request.remoteURL {
            return PlaybackResource(
                providerID: .subsonic,
                transport: .avPlayerURL(url)
            )
        }

        // Dynamically resolve authenticated short-lived stream URL from Subsonic client
        let providers = LibraryProviderRegistry.shared.allProviders().compactMap { $0 as? SubsonicLibraryProvider }
        if let provider = providers.first {
            let streamURL = try await provider.client.streamURL(id: request.itemID)
            return PlaybackResource(
                providerID: .subsonic,
                transport: .avPlayerURL(streamURL)
            )
        }

        throw SubsonicPlaybackError.missingRemoteURL
    }
}

private enum SubsonicPlaybackError: LocalizedError {
    case missingRemoteURL

    var errorDescription: String? {
        "Subsonic stream URL is missing."
    }
}
