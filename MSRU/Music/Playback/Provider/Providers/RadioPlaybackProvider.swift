//
//  RadioPlaybackProvider.swift
//  MSRU
//

import Foundation

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

// MARK: - Errors

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
