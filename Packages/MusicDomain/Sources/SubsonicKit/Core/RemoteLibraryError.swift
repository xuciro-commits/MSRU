//
//  LibraryProviderError.swift
//  SubsonicKit
//
//  Semantic typed errors for media library operations.
//

import Foundation

public enum RemoteLibraryError: LocalizedError, Sendable {
    case unreachable(serverURL: URL?)
    case timedOut
    case authenticationFailed(message: String)
    case incompatibleServer(details: String)
    case unsupportedCapability(capability: String)
    case resourceNotFound(id: String)
    case serverError(code: Int, message: String)
    case malformedResponse(details: String)
    case invalidURL(url: URL)
    case playbackUnavailable(reason: String)
    case operationCancelled

    public var errorDescription: String? {
        switch self {
        case .unreachable(let url):
            if let host = url?.host() ?? url?.host {
                return "Server at \(host) is currently unreachable."
            }
            return "Server is currently unreachable."
        case .timedOut:
            return "Request to media server timed out. Check network or server status."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .incompatibleServer(let details):
            return "Server is not compatible: \(details)"
        case .unsupportedCapability(let capability):
            return "This server does not support \(capability)."
        case .resourceNotFound(let id):
            return "Resource not found: \(id)"
        case .serverError(let code, let message):
            return "Server returned error (\(code)): \(message)"
        case .malformedResponse(let details):
            return "Received invalid response from server: \(details)"
        case .invalidURL(let url):
            return "Invalid URL constructed: \(url.absoluteString)"
        case .playbackUnavailable(let reason):
            return "Playback unavailable: \(reason)"
        case .operationCancelled:
            return "Operation was cancelled."
        }
    }
}
