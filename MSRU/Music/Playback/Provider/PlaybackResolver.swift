//
//  PlaybackResolver.swift
//  MSRU
//

import Foundation

// MARK: - Provider Registry

final class ProviderRegistry: @unchecked Sendable {

    private let lock = NSLock()
    private var storage: [PlaybackProviderID: any PlaybackProvider] = [:]

    // MARK: - Register

    func register(_ provider: any PlaybackProvider) {
        lock.lock()
        defer { lock.unlock() }
        storage[provider.id] = provider
    }

    // MARK: - Remove

    func remove(_ id: PlaybackProviderID) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: id)
    }

    // MARK: - Provider

    func provider(for id: PlaybackProviderID) -> (any PlaybackProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    // MARK: - Candidates

    func candidates(for request: PlaybackRequest) -> [any PlaybackProvider] {
        lock.lock()
        let providers = Array(storage.values)
        lock.unlock()

        return providers
            .filter { $0.canResolve(request) }
            .sorted { lhs, rhs in lhs.priority > rhs.priority }
    }
}

// MARK: - Playback Resolver

final class PlaybackResolver: Sendable {

    let registry: ProviderRegistry

    init(registry: ProviderRegistry) {
        self.registry = registry
    }

    func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
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

final class PlaybackProviderKernel: Sendable {

    let registry: ProviderRegistry
    let resolver: PlaybackResolver

    init(registry: ProviderRegistry) {
        self.registry = registry
        self.resolver = PlaybackResolver(registry: registry)
    }

    static func standard() -> PlaybackProviderKernel {
        let registry = ProviderRegistry()

        // Extended codecs first
        registry.register(ExtendedAudioPlaybackProvider())

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

    var errorDescription: String? {
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
