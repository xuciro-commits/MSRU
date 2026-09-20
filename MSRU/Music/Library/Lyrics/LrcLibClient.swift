//
//  LrcLibClient.swift
//  MSRU
//
//  Created for Open Synchronized Lyrics via LRCLIB.
//

import Foundation
import AppFoundation

/// Response payload from LRCLIB API.
nonisolated public struct LrcLibResponse: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?

    public init(
        id: Int? = nil,
        name: String? = nil,
        trackName: String? = nil,
        artistName: String? = nil,
        albumName: String? = nil,
        duration: Double? = nil,
        instrumental: Bool? = nil,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.id = id
        self.name = name
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }
}

/// Lightweight client for LRCLIB (open-source, free synchronized lyrics database).
public actor LrcLibClient {
    public static let shared = LrcLibClient()

    private let urlSession: URLSession
    private let baseURL = URL(string: "https://lrclib.net/api")!

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Fetches lyrics using exact metadata query.
    public func fetchLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LrcLibResponse? {
        var components = URLComponents(url: baseURL.appendingPathComponent("get"), resolvingAgainstBaseURL: true)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]

        if let albumName, !albumName.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: albumName))
        }
        if let duration, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MSRU/1.0.0 (https://github.com/xuciro/MSRU)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await urlSession.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                if httpRes.statusCode == 200 {
                    return try JSONDecoder().decode(LrcLibResponse.self, from: data)
                } else if httpRes.statusCode == 404 {
                    // Exact match not found, fallback to search
                    return try await searchLyrics(query: "\(artistName) \(trackName)")
                }
            }
            return nil
        } catch {
            // On network error or timeout, attempt a broad search as fallback
            return try? await searchLyrics(query: "\(artistName) \(trackName)")
        }
    }

    /// Searches for lyrics when exact metadata does not yield a match.
    public func searchLyrics(query: String) async throws -> LrcLibResponse? {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MSRU/1.0.0 (https://github.com/xuciro/MSRU)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            return nil
        }

        let results = try JSONDecoder().decode([LrcLibResponse].self, from: data)
        // Prefer one that has synced lyrics
        return results.first(where: { $0.syncedLyrics != nil && !($0.syncedLyrics?.isEmpty ?? true) })
            ?? results.first
    }
}
