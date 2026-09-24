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

    // MARK: - Cleaning & Script Helpers

    public static func cleanTrackTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"\s*[\(\[\{][^\)\]\}]*?(?:feat\.?|ft\.?|featuring|with|live|remaster(?:ed)?|deluxe|version|edition|mono|stereo|bonus|acoustic|radio edit|original mix)[^\)\]\}]*?[\)\]\}]"#,
            #"\s*-\s*(?:live|remaster(?:ed)?|deluxe|\d{4}\s*remaster).*?$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(title.startIndex..., in: title)
                title = regex.stringByReplacingMatches(in: title, options: [], range: range, withTemplate: "")
            }
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func cleanArtistName(_ raw: String) -> String {
        var artist = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = [" feat. ", " ft. ", " featuring ", " & ", " / ", ", "]
        for sep in separators {
            if let range = artist.range(of: sep, options: .caseInsensitive) {
                artist = String(artist[..<range.lowerBound])
                break
            }
        }
        return artist.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func scriptVariants(for text: String) -> [String] {
        var variants = [text]
        if let hans = (text as NSString).applyingTransform(StringTransform("Hant-Hans"), reverse: false), hans != text {
            variants.append(hans)
        }
        if let hant = (text as NSString).applyingTransform(StringTransform("Hant-Hans"), reverse: true), hant != text && !variants.contains(hant) {
            variants.append(hant)
        }
        return variants
    }

    public static func bestCandidate(from results: [LrcLibResponse], targetDuration: TimeInterval? = nil) -> LrcLibResponse? {
        guard !results.isEmpty else { return nil }

        let syncedCandidates = results.filter { $0.syncedLyrics != nil && !($0.syncedLyrics?.isEmpty ?? true) }
        let pool = syncedCandidates.isEmpty ? results : syncedCandidates

        if let targetDuration, targetDuration > 0 {
            return pool.min(by: { a, b in
                let diffA = abs((a.duration ?? 0) - targetDuration)
                let diffB = abs((b.duration ?? 0) - targetDuration)
                return diffA < diffB
            })
        }

        return pool.first
    }

    // MARK: - Internal HTTP Requests

    private func performGetRequest(queryItems: [URLQueryItem]) async -> LrcLibResponse? {
        var components = URLComponents(url: baseURL.appendingPathComponent("get"), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MSRU/1.0.0 (https://github.com/xuciro/MSRU)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6.0

        guard let (data, response) = try? await urlSession.data(for: request),
              let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            return nil
        }
        return try? JSONDecoder().decode(LrcLibResponse.self, from: data)
    }

    private func performSearchRequest(queryItems: [URLQueryItem]) async -> [LrcLibResponse] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("MSRU/1.0.0 (https://github.com/xuciro/MSRU)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6.0

        guard let (data, response) = try? await urlSession.data(for: request),
              let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            return []
        }
        return (try? JSONDecoder().decode([LrcLibResponse].self, from: data)) ?? []
    }

    // MARK: - Public API

    /// Multi-stage resilient lyrics resolver:
    /// 1. Exact GET with full metadata (track, artist, album, duration)
    /// 2. Exact GET without album (frequent false-404 caused by album tag mismatches)
    /// 3. Exact GET with track & artist only
    /// 4. Targeted SEARCH with track_name & artist_name (including Traditional/Simplified script variants)
    /// 5. Targeted SEARCH with cleaned track title & primary artist
    /// 6. General query SEARCH ("artist track")
    /// 7. Song-level fallback SEARCH (track_name only, duration-matched) for covers and tribute albums
    public func fetchLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LrcLibResponse? {
        let cleanTrack = Self.cleanTrackTitle(trackName)
        let cleanArtist = Self.cleanArtistName(artistName)

        // Stage 1: Exact GET with album & duration
        var getItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        if let albumName, !albumName.isEmpty {
            getItems.append(URLQueryItem(name: "album_name", value: albumName))
        }
        if let duration, duration > 0 {
            getItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        if let match = await performGetRequest(queryItems: getItems) {
            return match
        }

        // Stage 2: Exact GET without album (avoids false-404s from differing release editions)
        if albumName != nil {
            var itemsNoAlbum = [
                URLQueryItem(name: "track_name", value: trackName),
                URLQueryItem(name: "artist_name", value: artistName)
            ]
            if let duration, duration > 0 {
                itemsNoAlbum.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
            }
            if let match = await performGetRequest(queryItems: itemsNoAlbum) {
                return match
            }
        }

        // Stage 3: Exact GET with track & artist only
        if duration != nil {
            let itemsMinimal = [
                URLQueryItem(name: "track_name", value: trackName),
                URLQueryItem(name: "artist_name", value: artistName)
            ]
            if let match = await performGetRequest(queryItems: itemsMinimal) {
                return match
            }
        }

        // Stage 4: Targeted SEARCH with track_name and artist_name
        let artistVariants = Self.scriptVariants(for: artistName)
        let trackVariants = Self.scriptVariants(for: trackName)
        for t in trackVariants {
            for a in artistVariants {
                let results = await performSearchRequest(queryItems: [
                    URLQueryItem(name: "track_name", value: t),
                    URLQueryItem(name: "artist_name", value: a)
                ])
                if let best = Self.bestCandidate(from: results, targetDuration: duration) {
                    return best
                }
            }
        }

        // Stage 5: Targeted SEARCH with cleaned metadata if different
        if cleanTrack != trackName || cleanArtist != artistName {
            let cleanTrackVariants = Self.scriptVariants(for: cleanTrack)
            let cleanArtistVariants = Self.scriptVariants(for: cleanArtist)
            for t in cleanTrackVariants {
                for a in cleanArtistVariants {
                    let results = await performSearchRequest(queryItems: [
                        URLQueryItem(name: "track_name", value: t),
                        URLQueryItem(name: "artist_name", value: a)
                    ])
                    if let best = Self.bestCandidate(from: results, targetDuration: duration) {
                        return best
                    }
                }
            }
        }

        // Stage 6: Free-form query search
        let freeformQueries = [
            "\(cleanArtist) \(cleanTrack)",
            "\(artistName) \(trackName)"
        ]
        for query in Set(freeformQueries) {
            let results = await performSearchRequest(queryItems: [URLQueryItem(name: "q", value: query)])
            if let best = Self.bestCandidate(from: results, targetDuration: duration) {
                return best
            }
        }

        // Stage 7: Song-level fallback search by track title alone (duration-matched)
        // Crucial for cover artists (e.g. 陳果 covering 張國榮《拒絕再玩》), audiophile albums, tribute releases
        let titleFallbackVariants = Set(trackVariants + [cleanTrack])
        for t in titleFallbackVariants {
            let results = await performSearchRequest(queryItems: [URLQueryItem(name: "track_name", value: t)])
            if let best = Self.bestCandidate(from: results, targetDuration: duration) {
                return best
            }
            let qResults = await performSearchRequest(queryItems: [URLQueryItem(name: "q", value: t)])
            if let best = Self.bestCandidate(from: qResults, targetDuration: duration) {
                return best
            }
        }

        return nil
    }

    /// Searches for lyrics when exact metadata does not yield a match.
    public func searchLyrics(query: String) async throws -> LrcLibResponse? {
        let results = await performSearchRequest(queryItems: [URLQueryItem(name: "q", value: query)])
        return Self.bestCandidate(from: results)
    }

    /// Searches LRCLIB and returns all candidate matches for user manual selection.
    public func searchCandidates(query: String) async -> [LrcLibResponse] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [LrcLibResponse] = []
        var seenIDs = Set<Int>()

        // 1. General query search
        let qResults = await performSearchRequest(queryItems: [URLQueryItem(name: "q", value: trimmed)])
        for item in qResults {
            if let id = item.id, seenIDs.insert(id).inserted {
                candidates.append(item)
            }
        }

        // 2. Track name search
        let trackResults = await performSearchRequest(queryItems: [URLQueryItem(name: "track_name", value: trimmed)])
        for item in trackResults {
            if let id = item.id, seenIDs.insert(id).inserted {
                candidates.append(item)
            }
        }

        // 3. Script variants (Traditional / Simplified)
        if candidates.isEmpty {
            for v in Self.scriptVariants(for: trimmed) where v != trimmed {
                let vResults = await performSearchRequest(queryItems: [URLQueryItem(name: "q", value: v)])
                for item in vResults {
                    if let id = item.id, seenIDs.insert(id).inserted {
                        candidates.append(item)
                    }
                }
                if !candidates.isEmpty { break }
            }
        }

        return candidates
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

    /// Searches remote lyrics candidates matching a query string.
    public func searchCandidates(query: String) async -> [LrcLibResponse] {
        await LrcLibClient.shared.searchCandidates(query: query)
    }

    /// Applies a user-chosen candidate directly to the track context, saving it to the cache directory.
    public func applyCandidate(response: LrcLibResponse, context: LyricsQueryContext) -> LrcDocument? {
        let text = (response.syncedLyrics?.isEmpty == false ? response.syncedLyrics : response.plainLyrics) ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let doc = LrcParser.parse(trimmed)
        guard !doc.lines.isEmpty || !doc.plainText.isEmpty else { return nil }

        // Cache chosen lyrics locally
        let cacheFile = CachedLyricsProvider.cacheFileURL(context: context, cacheDirectory: cacheDirectory)
        try? trimmed.write(to: cacheFile, atomically: true, encoding: .utf8)

        return doc
    }

}
