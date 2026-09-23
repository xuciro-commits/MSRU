//
//  ArtistBiographyService.swift
//  MSRU
//
//  Created for Artist Biography, Genres & Encyclopedic Profile Enrichment.
//

import Foundation
import MusicDomain

/// Encyclopedic biography and profile record for an artist.
nonisolated public struct ArtistBiographyRecord: Codable, Sendable, Equatable {
    public let artistName: String
    public let summary: String
    public let sourceURL: URL?
    public let thumbnailURL: URL?
    public let genres: [String]
    public let lifeSpan: String?
    public let country: String?
    public let dateFetched: Date

    public init(
        artistName: String,
        summary: String,
        sourceURL: URL? = nil,
        thumbnailURL: URL? = nil,
        genres: [String] = [],
        lifeSpan: String? = nil,
        country: String? = nil,
        dateFetched: Date = Date()
    ) {
        self.artistName = artistName
        self.summary = summary
        self.sourceURL = sourceURL
        self.thumbnailURL = thumbnailURL
        self.genres = genres
        self.lifeSpan = lifeSpan
        self.country = country
        self.dateFetched = dateFetched
    }
}

/// Service that enriches artist profiles with biographies and genres from Wikipedia and MusicBrainz.
public actor ArtistBiographyService {
    public static let shared = ArtistBiographyService()

    private let urlSession: URLSession
    private let cacheDirectory: URL

    public init(urlSession: URLSession = .shared, cacheDirectory: URL? = nil) {
        self.urlSession = urlSession
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/ArtistBio", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.cacheDirectory = dir
        }
    }

    /// Fetches biographical information and genres for an artist, with automatic caching.
    public func fetchBiography(artistName: String, mbid: String? = nil) async -> ArtistBiographyRecord? {
        let cleanName = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName != "Unknown Artist" else { return nil }

        let cacheFile = cacheFileURL(artistName: cleanName)

        // 1. Check local cache
        if FileManager.default.fileExists(atPath: cacheFile.path),
           let data = try? Data(contentsOf: cacheFile),
           let cached = try? JSONDecoder().decode(ArtistBiographyRecord.self, from: data) {
            return cached
        }

        // 2. Fetch from Wikipedia summary (prefer Chinese, fallback to English)
        var wikiSummary: String? = nil
        var wikiSourceURL: URL? = nil
        var thumbnailURL: URL? = nil

        if let zhWiki = await fetchWikipediaSummary(title: cleanName, language: "zh") {
            wikiSummary = zhWiki.extract
            wikiSourceURL = zhWiki.pageURL
            thumbnailURL = zhWiki.thumbnailURL
        } else if let enWiki = await fetchWikipediaSummary(title: cleanName, language: "en") {
            wikiSummary = enWiki.extract
            wikiSourceURL = enWiki.pageURL
            thumbnailURL = enWiki.thumbnailURL
        }

        // 3. If MusicBrainz MBID is available or searchable, fetch genres and country
        var genres: [String] = []
        var country: String? = nil
        var lifeSpan: String? = nil

        if let mbid {
            if let mbInfo = await fetchMusicBrainzArtist(mbid: mbid) {
                genres = mbInfo.genres
                country = mbInfo.country
                lifeSpan = mbInfo.lifeSpan
            }
        }

        guard wikiSummary != nil || !genres.isEmpty || country != nil else {
            return nil
        }

        let record = ArtistBiographyRecord(
            artistName: cleanName,
            summary: wikiSummary ?? String(localized: "No biography available."),
            sourceURL: wikiSourceURL,
            thumbnailURL: thumbnailURL,
            genres: genres,
            lifeSpan: lifeSpan,
            country: country
        )

        // 4. Save to disk cache
        if let encoded = try? JSONEncoder().encode(record) {
            try? encoded.write(to: cacheFile, options: .atomic)
        }

        return record
    }

    private struct WikiSummaryResult {
        public let extract: String
        public let pageURL: URL?
        public let thumbnailURL: URL?
    }

    private func fetchWikipediaSummary(title: String, language: String) async -> WikiSummaryResult? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        guard let url = URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/summary/\(encoded)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MSRU/1.0.0 (https://github.com/xuciro/MSRU)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        guard let (data, response) = try? await urlSession.data(for: request),
              let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let extract = json["extract"] as? String, !extract.isEmpty else {
            return nil
        }

        var pageURL: URL? = nil
        if let contentURLs = json["content_urls"] as? [String: Any],
           let desktop = contentURLs["desktop"] as? [String: Any],
           let pageStr = desktop["page"] as? String {
            pageURL = URL(string: pageStr)
        }

        var thumbnailURL: URL? = nil
        if let thumb = json["thumbnail"] as? [String: Any],
           let source = thumb["source"] as? String {
            thumbnailURL = URL(string: source)
        }

        return WikiSummaryResult(extract: extract, pageURL: pageURL, thumbnailURL: thumbnailURL)
    }

    private struct MusicBrainzArtistResult {
        public let genres: [String]
        public let country: String?
        public let lifeSpan: String?
    }

    private func fetchMusicBrainzArtist(mbid: String) async -> MusicBrainzArtistResult? {
        guard let url = URL(string: "https://musicbrainz.org/ws/2/artist/\(mbid)?inc=genres&fmt=json") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("MSRU/1.0.0 (https://github.com/xuciro/MSRU)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        guard let (data, response) = try? await urlSession.data(for: request),
              let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var genres: [String] = []
        if let genresArr = json["genres"] as? [[String: Any]] {
            genres = genresArr.compactMap { $0["name"] as? String }
        }

        let country = json["country"] as? String

        var lifeSpan: String? = nil
        if let span = json["life-span"] as? [String: Any] {
            let begin = span["begin"] as? String
            let end = span["end"] as? String
            if let begin {
                lifeSpan = end != nil ? "\(begin) - \(end!)" : "\(begin) - \(String(localized: "Present"))"
            }
        }

        return MusicBrainzArtistResult(genres: genres, country: country, lifeSpan: lifeSpan)
    }

    private func cacheFileURL(artistName: String) -> URL {
        let safeName = artistName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return cacheDirectory.appendingPathComponent("\(safeName).json")
    }
}
