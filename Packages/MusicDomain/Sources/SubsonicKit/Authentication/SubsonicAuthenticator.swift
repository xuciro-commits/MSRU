//
//  SubsonicAuthenticator.swift
//  SubsonicKit
//
//  Standard token/salt authentication generator following Subsonic & OpenSubsonic specs.
//

import Foundation
import CryptoKit

public struct SubsonicAuthParameters: Sendable, Equatable {
    public let username: String
    public let token: String
    public let salt: String
    public let clientVersion: String
    public let clientName: String
    public let format: String

    public var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: clientVersion),
            URLQueryItem(name: "c", value: clientName),
            URLQueryItem(name: "f", value: format)
        ]
    }
}

public struct SubsonicAuthenticator: Sendable {
    public let clientVersion: String
    public let clientName: String

    public init(
        clientVersion: String = "1.16.1",
        clientName: String = "MSRU"
    ) {
        self.clientVersion = clientVersion
        self.clientName = clientName
    }

    /// Computes Subsonic token: MD5(password + salt)
    public static func computeToken(password: String, salt: String) -> String {
        let combined = password + salt
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Generates cryptographically secure random salt hex string.
    public static func generateSalt(length: Int = 12) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Generates modern token/salt parameters for an authenticated request.
    public func makeAuthParameters(username: String, password: String) -> SubsonicAuthParameters {
        let salt = Self.generateSalt()
        let token = Self.computeToken(password: password, salt: salt)

        return SubsonicAuthParameters(
            username: username,
            token: token,
            salt: salt,
            clientVersion: clientVersion,
            clientName: clientName,
            format: "json"
        )
    }

    /// Signs a given URL with authenticated query items.
    public func sign(url: URL, username: String, password: String, extraQueryItems: [URLQueryItem] = []) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let authParams = makeAuthParameters(username: username, password: password)
        var items = components.queryItems ?? []
        items.append(contentsOf: authParams.queryItems)
        items.append(contentsOf: extraQueryItems)
        components.queryItems = items
        return components.url ?? url
    }
}
