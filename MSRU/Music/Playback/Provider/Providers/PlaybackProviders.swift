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
    private let downloadStore: any RemoteAudioDownloading

    init(downloadStore: any RemoteAudioDownloading = RemoteAudioDownloadStore()) {
        self.downloadStore = downloadStore
    }

    func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .subsonic && (request.remoteURL != nil || !request.itemID.isEmpty)
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
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

    var errorDescription: String? {
        switch self {
        case .missingServerIdentity: "Subsonic playback needs a server identity or stream URL."
        case .serverUnavailable: "The selected Subsonic server is unavailable."
        }
    }
}
