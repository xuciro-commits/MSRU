//
//  PlaybackProviders.swift
//  MSRU
//

import Foundation
import MediaLibrary
import SubsonicKit
import MusicDomain
import MusicLibrary

// MARK: - Local Playback Provider

public struct LocalPlaybackProvider: PlaybackProvider {

    public let id: PlaybackProviderID = .local
    public let priority = 1_000
    private let codec = AppleAudioFileDecoder()

    public func canResolve(_ request: PlaybackRequest) -> Bool {
        guard request.source == .local, let url = request.localFileURL else {
            return false
        }
        guard !ExtendedAudioFormatSupport.supports(url) else {
            return false
        }
        return true
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
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

    nonisolated public init() {}
}

private enum LocalPlaybackProviderError: LocalizedError {
    case missingFileURL
    case invalidFileURL
    case fileNotFound(URL)

    public var errorDescription: String? {
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

public struct ExtendedAudioPlaybackProvider: PlaybackProvider {

    public let id: PlaybackProviderID = .extendedAudio
    public let priority = 2_000

    private let codec: any AudioCodecBackend

    public init(codec: any AudioCodecBackend = FFmpegCodecBackend()) {
        self.codec = codec
    }

    public func canResolve(_ request: PlaybackRequest) -> Bool {
        guard request.source == .local, let url = request.localFileURL else {
            return false
        }
        return codec.canDecode(url)
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
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

    public var errorDescription: String? {
        "Extended audio source file is missing."
    }
}

// MARK: - Openverse Playback Provider

public struct OpenversePlaybackProvider: PlaybackProvider {

    public let id: PlaybackProviderID = .openverse
    public let priority = 900

    public func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .openverse && request.remoteURL != nil
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
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

    nonisolated public init() {}
}

private enum OpenversePlaybackProviderError: LocalizedError {
    case missingURL
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Openverse returned no playable audio URL."
        case .invalidURL:
            return "Openverse returned an invalid audio URL."
        }
    }
}

// MARK: - Radio Playback Provider

public struct RadioPlaybackProvider: PlaybackProvider {

    public let id: PlaybackProviderID = .radio
    public let priority = 850

    public func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .radio && request.remoteURL != nil
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
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

    nonisolated public init() {}
}

private enum RadioPlaybackProviderError: LocalizedError {
    case missingStreamURL
    case invalidStreamURL

    public var errorDescription: String? {
        switch self {
        case .missingStreamURL:
            return "Radio station has no valid stream URL."
        case .invalidStreamURL:
            return "Radio station stream URL must use http or https scheme."
        }
    }
}

// MARK: - Remote Subsonic Playback Provider

public struct RemoteSubsonicPlaybackProvider: PlaybackProvider {

    public let id: PlaybackProviderID = .subsonic
    public let priority = 950
    private let downloadStore: any RemoteAudioDownloading

    public init(downloadStore: any RemoteAudioDownloading = RemoteAudioDownloadStore()) {
        self.downloadStore = downloadStore
    }

    public func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .subsonic && (request.remoteURL != nil || !request.itemID.isEmpty)
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        let streamURL: URL
        if let serverID = request.subsonicServerID {
            guard let provider = LibraryProviderRegistry.shared.provider(for: LibrarySourceID(serverID)) as? SubsonicLibraryProvider else {
                throw SubsonicPlaybackError.serverUnavailable
            }
            streamURL = try provider.client.streamURL(id: request.itemID)
        } else if let url = request.remoteURL {
            streamURL = url
        } else {
            throw SubsonicPlaybackError.missingServerIdentity
        }

        guard request.prefersPreparedPCM else {
            return PlaybackResource(providerID: .subsonic, transport: .avPlayerURL(streamURL))
        }

        // Download to a temporary file before decoding. A session owns the file
        // through playback and removes it on close, including stale prefetches.
        let fileURL = try await downloadStore.download(streamURL)
        do {
            let decoded: AudioCodecOpenResult
            do {
                decoded = try await AppleAudioFileDecoder().open(fileURL)
            } catch {
                decoded = try await FFmpegCodecBackend().open(fileURL)
            }
            if Task.isCancelled {
                await decoded.session.close()
                throw CancellationError()
            }
            return PlaybackResource(
                providerID: .subsonic,
                transport: .decodedPCM(PCMPlaybackResource(
                    format: decoded.format,
                    session: DownloadedPCMDecodeSession(
                        wrapped: decoded.session,
                        fileURL: fileURL,
                        downloadStore: downloadStore
                    )
                )),
                duration: decoded.format.duration
            )
        } catch is CancellationError {
            await downloadStore.remove(fileURL)
            throw CancellationError()
        } catch {
            // A stream may use a codec available to AVPlayer only.
            await downloadStore.remove(fileURL)
            return PlaybackResource(providerID: .subsonic, transport: .avPlayerURL(streamURL))
        }
    }
}

private enum SubsonicPlaybackError: LocalizedError {
    case missingServerIdentity
    case serverUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingServerIdentity: "Subsonic playback needs a server identity or stream URL."
        case .serverUnavailable: "The selected Subsonic server is unavailable."
        }
    }
}
