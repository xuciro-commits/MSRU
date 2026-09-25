//
//  PlaybackResolver.swift
//  MSRU
//

import Foundation
import MusicDomain
import MusicLibrary

// MARK: - Provider Registry

public final class ProviderRegistry: @unchecked Sendable {

    private let lock = NSLock()
    private var storage: [PlaybackProviderID: any PlaybackProvider] = [:]

    // MARK: - Register

    public func register(_ provider: any PlaybackProvider) {
        lock.lock()
        defer { lock.unlock() }
        storage[provider.id] = provider
    }

    // MARK: - Remove

    public func remove(_ id: PlaybackProviderID) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: id)
    }

    // MARK: - Provider

    public func provider(for id: PlaybackProviderID) -> (any PlaybackProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    // MARK: - Candidates

    public func candidates(for request: PlaybackRequest) -> [any PlaybackProvider] {
        lock.lock()
        let providers = Array(storage.values)
        lock.unlock()

        return providers
            .filter { $0.canResolve(request) }
            .sorted { lhs, rhs in lhs.priority > rhs.priority }
    }

    nonisolated public init() {}
}

// MARK: - Playback Resolver

public final class PlaybackResolver: Sendable {

    public let registry: ProviderRegistry

    public init(registry: ProviderRegistry) {
        self.registry = registry
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        // Specific provider requested
        if let providerHint = request.providerHint,
           let provider = registry.provider(for: providerHint),
           provider.canResolve(request) {
            do {
                return try await provider.resolve(request)
            } catch {
                throw PlaybackResolutionError.providerFailed(
                    providerID: provider.id,
                    message: error.localizedDescription
                )
            }
        }

        let candidates = registry.candidates(for: request)

        guard !candidates.isEmpty else {
            throw PlaybackResolutionError.noProvider(
                source: request.source,
                formatHint: request.localFileURL?.pathExtension.uppercased()
            )
        }

        var lastError: Error?

        for provider in candidates {
            do {
                return try await provider.resolve(request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        throw PlaybackResolutionError.noProvider(
            source: request.source,
            formatHint: request.localFileURL?.pathExtension.uppercased()
        )
    }
}

// MARK: - Playback Provider Kernel

public final class PlaybackProviderKernel: Sendable {

    public let registry: ProviderRegistry
    public let resolver: PlaybackResolver

    public init(registry: ProviderRegistry) {
        self.registry = registry
        self.resolver = PlaybackResolver(registry: registry)
    }

    public static func standard() -> PlaybackProviderKernel {
        let registry = ProviderRegistry()

        // Extended codecs first
        registry.register(ExtendedAudioPlaybackProvider())

        // Apple Music (MusicKit-based playback)
        registry.register(AppleMusicPlaybackProvider())

        // Apple-native local media
        registry.register(LocalPlaybackProvider())

        // Remote media
        registry.register(OpenversePlaybackProvider())

        // Radio live streaming
        registry.register(RadioPlaybackProvider())

        // Subsonic / OpenSubsonic remote streaming
        registry.register(RemoteSubsonicPlaybackProvider())

        return PlaybackProviderKernel(registry: registry)
    }
}

// MARK: - Errors

private enum PlaybackResolutionError: LocalizedError {

    case noProvider(
        source: PlaybackRequest.Source,
        formatHint: String? = nil
    )

    case providerFailed(
        providerID: PlaybackProviderID,
        message: String
    )

    public var errorDescription: String? {
        switch self {
        case .noProvider(let source, let formatHint):
            if let formatHint, !formatHint.isEmpty {
                return "Format .\(formatHint) is currently not supported by playback engine."
            }
            return "No playback provider can resolve \(source.rawValue)."

        case .providerFailed(let providerID, let message):
            return "\(providerID.rawValue) playback failed: \(message)"
        }
    }
}
