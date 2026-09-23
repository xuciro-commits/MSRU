//
//  LyricsService.swift
//  MSRU
//
//  Created for Multi-Tier Synchronized Lyrics Loading, Caching & Playback Synchronization.
//

import Foundation
import Observation
import AVFoundation
import AppFoundation
import MusicDomain

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
                    return try await searchLyrics(query: "\(artistName) \(trackName)")
                }
            }
            return nil
        } catch {
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
        return results.first(where: { $0.syncedLyrics != nil && !($0.syncedLyrics?.isEmpty ?? true) })
            ?? results.first
    }
}

/// Multi-tier lyrics retrieval service driven by a pluggable provider chain.
///
/// Default provider order:
/// 1. Local companion `.lrc` file
/// 2. Local persistent cache
/// 3. Embedded audio metadata (USLT / LYRICS)
/// 4. OpenSubsonic song ID (when present)
/// 5. LRCLIB public API
///
public actor LyricsService {
    public static let shared = LyricsService()

    public nonisolated let cacheDirectory: URL
    private let providers: [any LyricsProvider]

    public init(
        providers: [any LyricsProvider]? = nil,
        cacheDirectory: URL? = nil
    ) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Lyrics", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.cacheDirectory = dir
        }

        self.providers = providers ?? [
            LocalCompanionLyricsProvider(),
            CachedLyricsProvider(cacheDirectory: self.cacheDirectory),
            EmbeddedTagLyricsProvider(),
            SubsonicLyricsProvider(),
            LrcLibLyricsProvider()
        ]
    }

    /// Resolves lyrics by evaluating the provider chain in order.
    /// The first provider returning a non-empty result wins; the result is
    /// parsed into an `LrcDocument` and cached locally for offline replay.
    public func resolveLyrics(context: LyricsQueryContext) async -> LrcDocument? {
        let cleanTitle = context.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        for provider in providers {
            do {
                if let lyricsText = try await provider.fetchLyrics(context: context),
                   !lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let doc = LrcParser.parse(lyricsText)
                    if !doc.lines.isEmpty || !doc.plainText.isEmpty {
                        // Cache remotely fetched lyrics locally for offline use
                        if !(provider is LocalCompanionLyricsProvider) && !(provider is CachedLyricsProvider) {
                            let cacheFile = CachedLyricsProvider.cacheFileURL(
                                context: context,
                                cacheDirectory: cacheDirectory
                            )
                            try? lyricsText.write(to: cacheFile, atomically: true, encoding: .utf8)
                        }
                        return doc
                    }
                }
            } catch {
                print("[LyricsService] Provider \(provider.providerName) error: \(error.localizedDescription)")
                continue
            }
        }

        return nil
    }

    /// Backward-compatible convenience overload.
    public func resolveLyrics(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        fileURL: URL? = nil
    ) async -> LrcDocument? {
        let context = LyricsQueryContext(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            fileURL: fileURL
        )
        return await resolveLyrics(context: context)
    }

}
