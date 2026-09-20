//
//  AcoustIDConfiguration.swift
//  MSRU
//
//  Created for Acoustic Metadata Pipeline Architecture.
//

import Foundation

/// Persistent configuration and credential management for the AcoustID web service.
public actor AcoustIDConfiguration {

    public static let shared = AcoustIDConfiguration()

    private let defaults: UserDefaults
    private let keyName = "MSRU_AcoustID_API_Key"
    private let defaultKey = "eKeKSuffE6"

    private var cachedKey: String?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The active AcoustID client API key used for fingerprint lookups.
    public var apiKey: String {
        get {
            if let cached = cachedKey {
                return cached
            }
            let key = defaults.string(forKey: keyName) ?? defaultKey
            cachedKey = key
            return key
        }
    }

    /// Updates the AcoustID API key.
    public func setApiKey(_ newKey: String) {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalVal = trimmed.isEmpty ? defaultKey : trimmed
        defaults.set(finalVal, forKey: keyName)
        cachedKey = finalVal
    }

    /// Tests the connectivity of the current API key against the official AcoustID ping/lookup endpoint.
    public func verifyConnectivity() async -> (success: Bool, message: String) {
        let currentKey = apiKey
        let testDuration = 200
        let endpoint = "https://api.acoustid.org/v2/lookup?client=\(currentKey)&duration=\(testDuration)"
        guard let url = URL(string: endpoint) else {
            return (false, "Invalid URL endpoint")
        }

        var req = URLRequest(url: url, timeoutInterval: 8.0)
        req.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return (false, "No HTTP response")
            }

            if http.statusCode == 200 {
                return (true, "Connected successfully to AcoustID API (Status 200 OK)")
            } else if http.statusCode == 401 || http.statusCode == 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let msg = error["message"] as? String {
                    return (false, "AcoustID Error: \(msg)")
                }
                return (false, "AcoustID returned status code \(http.statusCode)")
            } else {
                return (false, "HTTP \(http.statusCode)")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }
}
