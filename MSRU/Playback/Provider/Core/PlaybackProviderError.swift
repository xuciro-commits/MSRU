//
//  PlaybackProviderError.swift
//  MSRU
//

import Foundation


enum PlaybackProviderError:
    LocalizedError,
    Sendable {

    case noProviderAvailable(
        trackID:
            String
    )

    case unsupportedRequest(
        providerID:
            PlaybackProviderID
    )

    case resourceUnavailable(
        providerID:
            PlaybackProviderID,
        reason:
            String?
    )

    case fileMissing(
        URL
    )

    case authenticationRequired(
        providerID:
            PlaybackProviderID
    )

    case unsupportedQuality(
        providerID:
            PlaybackProviderID,
        quality:
            PlaybackQuality
    )

    case network(
        providerID:
            PlaybackProviderID,
        message:
            String
    )

    case timeout(
        providerID:
            PlaybackProviderID
    )

    case rateLimited(
        providerID:
            PlaybackProviderID,
        retryAfter:
            TimeInterval?
    )

    case invalidResponse(
        providerID:
            PlaybackProviderID
    )

    case providerFailure(
        providerID:
            PlaybackProviderID,
        message:
            String
    )


    // MARK: - Description

    var errorDescription:
        String? {

        switch self {

        case .noProviderAvailable(
            let trackID
        ):

            return
                "No playback provider is available for track \(trackID)."


        case .unsupportedRequest(
            let providerID
        ):

            return
                "\(providerID.rawValue) cannot resolve this playback request."


        case .resourceUnavailable(
            let providerID,
            let reason
        ):

            if let reason {

                return
                    "\(providerID.rawValue) resource is unavailable: \(reason)"
            }

            return
                "\(providerID.rawValue) resource is unavailable."


        case .fileMissing(
            let url
        ):

            return
                "Local audio file is missing: \(url.lastPathComponent)"


        case .authenticationRequired(
            let providerID
        ):

            return
                "\(providerID.rawValue) requires authentication."


        case .unsupportedQuality(
            let providerID,
            let quality
        ):

            return
                "\(providerID.rawValue) does not support \(quality.rawValue) quality."


        case .network(
            let providerID,
            let message
        ):

            return
                "\(providerID.rawValue) network error: \(message)"


        case .timeout(
            let providerID
        ):

            return
                "\(providerID.rawValue) request timed out."


        case .rateLimited(
            let providerID,
            let retryAfter
        ):

            if let retryAfter {

                return
                    "\(providerID.rawValue) is rate limited. Retry after \(retryAfter) seconds."
            }

            return
                "\(providerID.rawValue) is rate limited."


        case .invalidResponse(
            let providerID
        ):

            return
                "\(providerID.rawValue) returned an invalid response."


        case .providerFailure(
            let providerID,
            let message
        ):

            return
                "\(providerID.rawValue) failed: \(message)"
        }
    }
}
