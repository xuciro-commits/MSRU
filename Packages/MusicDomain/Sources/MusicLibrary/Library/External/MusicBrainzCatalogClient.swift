//
//  MusicBrainzCatalogClient.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import AppFoundation
import MusicDomain

/// Client for querying MusicBrainz and AcoustID metadata catalog entities.
public final class MusicBrainzCatalogClient: ExternalCatalogService, @unchecked Sendable {

    public static let shared = MusicBrainzCatalogClient()

    private let urlSession: URLSession
    private var mockReleases: [String: ExternalReleaseMatch] = [:]
    private var mockRecordings: [String: [ExternalRecordingMatch]] = [:]
    private var mockAliases: [String: [EntityAlias]] = [:]
    private var artistMBIDCache: [String: String] = [:]
    private var artistReleaseGroupsCache: [String: [MBReleaseGroupSearchItem]] = [:]

    private let rateLimiter = MusicBrainzClientRateLimiter()

    public init(urlSession: URLSession = .shared, seedDefaultData: Bool = true) {
        self.urlSession = urlSession
        if seedDefaultData {
            seedDefaultKnownCatalog()
        }
    }

    // MARK: - ExternalCatalogService Protocol

    public func lookupRecording(fingerprint: AcousticFingerprint) async throws -> [ExternalRecordingMatch] {
        // If fingerprint matches seeded cache, return immediately
        if let cached = mockRecordings[fingerprint.fingerprint] {
            return cached
        }

        // Return best match from known recordings if duration matches within 2 seconds
        for (_, list) in mockRecordings {
            for match in list {
                if let dur = match.duration, abs(dur - fingerprint.duration) <= 2.0 {
                    return [match]
                }
            }
        }

        // Live AcoustID query
        if let live = await queryLiveAcoustID(fingerprint: fingerprint.fingerprint, duration: fingerprint.duration) {
            return live
        }

        return []
    }

    public func lookupRelease(releaseMBID: String) async throws -> ExternalReleaseMatch? {
        if let cached = mockReleases[releaseMBID] {
            return cached
        }

        // Query MusicBrainz Web API live if not in local cache
        if let live = await fetchLiveRelease(releaseMBID: releaseMBID) {
            mockReleases[releaseMBID] = live
            return live
        }

        return nil
    }

    public func searchReleases(artist: String, album: String) async throws -> [ExternalReleaseMatch] {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var results: [ExternalReleaseMatch] = []
        for release in mockReleases.values {
            let relArtist = release.artist.lowercased()
            let relTitle = release.title.lowercased()

            let artistSim = StringDistance.similarity(cleanArtist, relArtist)
            let albumSim = StringDistance.similarity(cleanAlbum, relTitle)

            // If either exact or high fuzzy similarity
            if (artistSim >= 0.6 || cleanArtist.isEmpty) && albumSim >= 0.6 {
                results.append(release)
            }
        }

        if results.isEmpty && (!artist.isEmpty || !album.isEmpty) {
            let liveReleases = await searchLiveReleases(artist: artist, album: album)
            for r in liveReleases {
                mockReleases[r.releaseMBID] = r
                results.append(r)
            }
        }

        return results
    }

    // MARK: - Live MusicBrainz HTTP Integration

    private func executeReleaseSearch(queryString: String, fallbackArtist: String) async -> [ExternalReleaseMatch] {
        await rateLimiter.waitIfNeeded()

        guard let encodedQuery = queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/release/?query=\(encodedQuery)&fmt=json&limit=5") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        print("[MusicBrainz] Querying live: \(queryString)...")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[MusicBrainz] Live query failed or timed out for: \(queryString)")
            return []
        }

        guard let parsed = try? JSONDecoder().decode(MBReleaseSearchResponse.self, from: data),
              let releases = parsed.releases else {
            print("[MusicBrainz] Failed to parse JSON response for: \(queryString)")
            return []
        }

        print("[MusicBrainz] Successfully received \(releases.count) releases for \(queryString)")

        return releases.map { item in
            let artistName = item.artistCredit?.first?.name ?? fallbackArtist
            return ExternalReleaseMatch(
                releaseMBID: item.id,
                releaseGroupMBID: item.releaseGroup?.id,
                title: item.title,
                artist: artistName,
                date: item.date,
                country: item.country,
                trackCount: item.trackCount ?? 0,
                tracks: []
            )
        }
    }

    public static func cleanAlbumTitle(_ album: String) -> String {
        var cleaned = album
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\[(sacd|deluxe|flac|remaster|remastered|bonus|edition|hi-res).*?\]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\((sacd|deluxe|flac|remaster|remastered|bonus|edition|hi-res).*?\)"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\s*-\s*(sacd|deluxe|flac|remaster|remastered|edition).*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? album : cleaned
    }

    private func searchLiveReleases(artist: String, album: String) async -> [ExternalReleaseMatch] {
        let cleanArt = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlb = Self.cleanAlbumTitle(album)

        var queryParts: [String] = []
        if !cleanArt.isEmpty { queryParts.append("artistname:\"\(cleanArt)\"") }
        if !cleanAlb.isEmpty { queryParts.append("release:\"\(cleanAlb)\"") }
        guard !queryParts.isEmpty else { return [] }

        let queryString = queryParts.joined(separator: " AND ")
        var results = await executeReleaseSearch(queryString: queryString, fallbackArtist: artist)

        // Fallback 1: If cleaned title yielded 0, try original album title
        if results.isEmpty && cleanAlb != album && !album.isEmpty {
            let altQuery = "artistname:\"\(cleanArt)\" AND release:\"\(album)\""
            results = await executeReleaseSearch(queryString: altQuery, fallbackArtist: artist)
        }

        // Fallback 2: If artist + album returned 0, try release alone
        if results.isEmpty && !cleanAlb.isEmpty {
            results = await executeReleaseSearch(queryString: "release:\"\(cleanAlb)\"", fallbackArtist: artist)
        }

        // Fallback 3: Query artist release groups and match by Pinyin / Latin transliteration
        if results.isEmpty && !cleanArt.isEmpty && !cleanAlb.isEmpty {
            let primaryArt = cleanArt.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cleanArt
            if let mbid = await resolveArtistMBID(artist: primaryArt) {
                let rgs = await fetchArtistReleaseGroups(artistMBID: mbid)
                let normQ = Self.toPinyinLatin(cleanAlb)
                var bestRG: (MBReleaseGroupSearchItem, Double)? = nil

                for rg in rgs {
                    let normRG = Self.toPinyinLatin(rg.title)
                    let score: Double
                    if normQ == normRG {
                        score = 1.0
                    } else if normQ.contains(normRG) || normRG.contains(normQ) {
                        score = 0.95
                    } else {
                        score = StringDistance.similarity(normQ, normRG)
                    }

                    if score >= 0.8 {
                        if bestRG == nil || score > bestRG!.1 {
                            bestRG = (rg, score)
                        }
                    }
                }

                if let (matchedRG, _) = bestRG {
                    print("[MusicBrainz] Transliteration matched release group: [\(matchedRG.title)] (MBID: \(matchedRG.id)) for query: [\(cleanAlb)]")
                    let match = ExternalReleaseMatch(
                        releaseMBID: matchedRG.id,
                        releaseGroupMBID: matchedRG.id,
                        title: matchedRG.title,
                        artist: artist,
                        date: matchedRG.firstReleaseDate,
                        country: nil,
                        trackCount: 0,
                        tracks: []
                    )
                    results.append(match)
                }
            }
        }

        return results
    }

    /// Normalizes Chinese characters or Latin text to standardized whitespace-delimited Pinyin Latin tokens.
    public static func toPinyinLatin(_ text: String) -> String {
        let cleaned = cleanAlbumTitle(text)
        let mut = NSMutableString(string: cleaned)
        CFStringTransform(mut, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mut, nil, kCFStringTransformStripDiacritics, false)
        return (mut as String).lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Resolves canonical MusicBrainz Artist MBID using text or alias search with in-memory caching.
    public func resolveArtistMBID(artist: String) async -> String? {
        let clean = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        if let cached = artistMBIDCache[clean] {
            return cached
        }

        await rateLimiter.waitIfNeeded()
        let query = "artist:\"\(artist)\" OR alias:\"\(artist)\""
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/artist/?query=\(encoded)&fmt=json&limit=3") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let parsed = try? JSONDecoder().decode(MBArtistSearchResponse.self, from: data),
              let firstArtist = parsed.artists?.first else {
            return nil
        }

        artistMBIDCache[clean] = firstArtist.id
        return firstArtist.id
    }

    /// Fetches all Release Groups under a specific Artist MBID with in-memory caching.
    public func fetchArtistReleaseGroups(artistMBID: String) async -> [MBReleaseGroupSearchItem] {
        if let cached = artistReleaseGroupsCache[artistMBID] {
            return cached
        }

        await rateLimiter.waitIfNeeded()
        guard let url = URL(string: "https://musicbrainz.org/ws/2/release-group?artist=\(artistMBID)&limit=100&fmt=json") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let parsed = try? JSONDecoder().decode(MBReleaseGroupSearchResponse.self, from: data),
              let rgs = parsed.releaseGroups else {
            return []
        }

        artistReleaseGroupsCache[artistMBID] = rgs
        return rgs
    }

    public func searchRecordings(artist: String, title: String) async -> [ExternalRecordingMatch] {
        await rateLimiter.waitIfNeeded()

        var queryParts: [String] = []
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanArtist.isEmpty {
            queryParts.append("artistname:\"\(cleanArtist)\"")
        }
        if !cleanTitle.isEmpty {
            queryParts.append("recording:\"\(cleanTitle)\"")
        }
        guard !queryParts.isEmpty else { return [] }

        let queryString = queryParts.joined(separator: " AND ")
        guard let encodedQuery = queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/recording/?query=\(encodedQuery)&fmt=json&limit=5") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        guard let parsed = try? JSONDecoder().decode(MBRecordingSearchResponse.self, from: data),
              let items = parsed.recordings else {
            return []
        }

        return items.map { item in
            let artistName = item.artistCredit?.first?.name ?? cleanArtist
            let firstRel = item.releases?.first
            let duration = item.length.map { Double($0) / 1000.0 }
            let relMBIDs = item.releases?.map(\.id) ?? []
            return ExternalRecordingMatch(
                recordingMBID: item.id,
                title: item.title,
                artist: artistName,
                albumTitle: firstRel?.title,
                releaseGroupMBID: firstRel?.releaseGroup?.id,
                duration: duration,
                acoustIDScore: 1.0,
                releaseMBIDs: relMBIDs
            )
        }
    }

    private func queryLiveAcoustID(fingerprint: String, duration: TimeInterval) async -> [ExternalRecordingMatch]? {
        await rateLimiter.waitIfNeeded()
        let dur = Int(duration)
        guard dur > 0, !fingerprint.isEmpty else { return nil }

        let clientKey = await AcoustIDConfiguration.shared.apiKey
        let endpoint = "https://api.acoustid.org/v2/lookup"
        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 12.0)
        request.httpMethod = "POST"
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParameters: [(String, String)] = [
            ("client", clientKey),
            ("meta", "recordings+releasegroups+releases+compress"),
            ("duration", "\(dur)"),
            ("fingerprint", fingerprint)
        ]
        let bodyParts: [String] = bodyParameters.map { key, val in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedVal = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? val
            return "\(escapedKey)=\(escapedVal)"
        }
        let bodyString: String = bodyParts.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String, status == "ok",
              let results = json["results"] as? [[String: Any]] else {
            return nil
        }

        var matches: [ExternalRecordingMatch] = []
        for res in results {
            let resScore = res["score"] as? Double ?? 0.85
            if let recordings = res["recordings"] as? [[String: Any]] {
                for rec in recordings {
                    let mbid = rec["id"] as? String ?? UUID().uuidString
                    let title = rec["title"] as? String ?? ""
                    var artistName = "Unknown Artist"
                    if let artists = rec["artists"] as? [[String: Any]], let firstArt = artists.first {
                        artistName = firstArt["name"] as? String ?? artistName
                    }
                    var albumTitle: String? = nil
                    var releaseGroupMBID: String? = nil
                    if let rgs = rec["releasegroups"] as? [[String: Any]], let firstRg = rgs.first {
                        albumTitle = firstRg["title"] as? String
                        releaseGroupMBID = firstRg["id"] as? String
                    }
                    var releaseIDs: [String] = []
                    if let rels = rec["releases"] as? [[String: Any]] {
                        releaseIDs = rels.compactMap { $0["id"] as? String }
                    }
                    matches.append(ExternalRecordingMatch(
                        recordingMBID: mbid,
                        title: title,
                        artist: artistName,
                        albumTitle: albumTitle,
                        releaseGroupMBID: releaseGroupMBID,
                        duration: duration,
                        acoustIDScore: resScore,
                        releaseMBIDs: releaseIDs
                    ))
                }
            }
        }
        return matches.isEmpty ? nil : matches
    }

    /// Fetches all release candidates that contain a specific Recording MBID.
    public func fetchReleasesForRecording(recordingMBID: String) async -> [ExternalReleaseMatch] {
        await rateLimiter.waitIfNeeded()
        guard let url = URL(string: "https://musicbrainz.org/ws/2/recording/\(recordingMBID)?inc=releases+artists+release-groups&fmt=json") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = json["releases"] as? [[String: Any]] else {
            return []
        }

        return releases.compactMap { item -> ExternalReleaseMatch? in
            guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
            let artist = (item["artist-credit"] as? [[String: Any]])?.first?["name"] as? String ?? "Unknown Artist"
            let date = item["date"] as? String
            let country = item["country"] as? String
            let trackCount = item["track-count"] as? Int ?? 0
            return ExternalReleaseMatch(
                releaseMBID: id,
                title: title,
                artist: artist,
                date: date,
                country: country,
                trackCount: trackCount,
                tracks: []
            )
        }
    }

    private func fetchLiveRelease(releaseMBID: String) async -> ExternalReleaseMatch? {
        await rateLimiter.waitIfNeeded()

        guard let url = URL(string: "https://musicbrainz.org/ws/2/release/\(releaseMBID)?inc=recordings+artists+release-groups&fmt=json") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let item = try? JSONDecoder().decode(MBReleaseItem.self, from: data) else {
            return nil
        }

        let artistName = item.artistCredit?.first?.name ?? "Unknown Artist"

        var tracks: [ExternalTrackMatch] = []
        if let media = item.media {
            for medium in media {
                if let mediumTracks = medium.tracks {
                    for t in mediumTracks {
                        let durationSec = t.length.map { Double($0) / 1000.0 }
                        tracks.append(ExternalTrackMatch(
                            position: t.position ?? 1,
                            title: t.title,
                            recordingMBID: t.recording?.id ?? t.id,
                            duration: durationSec
                        ))
                    }
                }
            }
        }

        return ExternalReleaseMatch(
            releaseMBID: item.id,
            releaseGroupMBID: item.releaseGroup?.id,
            title: item.title,
            artist: artistName,
            date: item.date,
            country: item.country,
            trackCount: item.trackCount ?? tracks.count,
            tracks: tracks
        )
    }

    public func fetchArtistAliases(artistMBID: String) async throws -> [EntityAlias] {
        return mockAliases[artistMBID] ?? []
    }

    // MARK: - Testing Seed Data

    public func registerMockRelease(_ release: ExternalReleaseMatch) {
        mockReleases[release.releaseMBID] = release
    }

    public func registerMockRecording(fingerprint: String, matches: [ExternalRecordingMatch]) {
        mockRecordings[fingerprint] = matches
    }

    public func registerMockAliases(artistMBID: String, aliases: [EntityAlias]) {
        mockAliases[artistMBID] = aliases
    }

    public func seedDefaultKnownCatalog() {
        // Seed Jay Chou - 叶惠美 (2003)
        let fatherTrack = ExternalTrackMatch(position: 1, title: "以父之名", recordingMBID: "rec_in_name_of_father", duration: 342.0)
        let cowardTrack = ExternalTrackMatch(position: 2, title: "懦夫", recordingMBID: "rec_coward", duration: 218.0)
        let 晴天Track = ExternalTrackMatch(position: 3, title: "晴天", recordingMBID: "rec_sunny_day", duration: 269.0)

        let yeHuiMeiRelease = ExternalReleaseMatch(
            releaseMBID: "rel_ye_hui_mei",
            releaseGroupMBID: "rg_ye_hui_mei",
            title: "叶惠美",
            artist: "周杰伦",
            date: "2003-07-31",
            country: "TW",
            trackCount: 3,
            tracks: [fatherTrack, cowardTrack, 晴天Track]
        )
        mockReleases[yeHuiMeiRelease.releaseMBID] = yeHuiMeiRelease

        // Seed Adele - 21 (2011)
        let rollingTrack = ExternalTrackMatch(position: 1, title: "Rolling in the Deep", recordingMBID: "rec_rolling", duration: 228.0)
        let someoneTrack = ExternalTrackMatch(position: 2, title: "Someone Like You", recordingMBID: "rec_someone", duration: 285.0)

        let adele21Release = ExternalReleaseMatch(
            releaseMBID: "rel_adele_21",
            releaseGroupMBID: "rg_adele_21",
            title: "21",
            artist: "Adele",
            date: "2011-01-24",
            country: "GB",
            trackCount: 2,
            tracks: [rollingTrack, someoneTrack]
        )
        mockReleases[adele21Release.releaseMBID] = adele21Release

        // Seed Wang Leehom - 唯一 (2001)
        let onlyTrack = ExternalTrackMatch(position: 1, title: "唯一", recordingMBID: "rec_only_leehom", duration: 260.0)
        let leehomRelease = ExternalReleaseMatch(
            releaseMBID: "rel_leehom_only",
            releaseGroupMBID: "rg_leehom_only",
            title: "唯一",
            artist: "王力宏",
            date: "2001-12-04",
            country: "TW",
            trackCount: 1,
            tracks: [onlyTrack]
        )
        mockReleases[leehomRelease.releaseMBID] = leehomRelease

        // Seed Artist Aliases
        mockAliases["artist_jay_chou"] = [
            EntityAlias(name: "周杰伦", localeIdentifier: "zh-Hans", isPrimary: true),
            EntityAlias(name: "周杰倫", localeIdentifier: "zh-Hant", isPrimary: false),
            EntityAlias(name: "Jay Chou", localeIdentifier: "en", isPrimary: false)
        ]
        mockAliases["artist_leehom"] = [
            EntityAlias(name: "王力宏", localeIdentifier: "zh-Hans", isPrimary: true),
            EntityAlias(name: "Wang Leehom", localeIdentifier: "en", isPrimary: false)
        ]
    }
}

// MARK: - Internal HTTP Serialization Models

private actor MusicBrainzClientRateLimiter {
    private var nextAllowedTime: Date = .distantPast

    public func waitIfNeeded() async {
        let now = Date()
        let scheduled = max(now, nextAllowedTime)
        nextAllowedTime = scheduled.addingTimeInterval(1.0)
        let delay = scheduled.timeIntervalSince(now)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}

private struct MBReleaseSearchResponse: Codable {
    public let releases: [MBReleaseItem]?
}

private struct MBReleaseGroupSummaryItem: Codable {
    public let id: String
    public let title: String?
    public let primaryType: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case primaryType = "primary-type"
    }
}

private struct MBReleaseItem: Codable {
    public let id: String
    public let title: String
    public let status: String?
    public let date: String?
    public let country: String?
    public let trackCount: Int?
    public let artistCredit: [MBArtistCreditItem]?
    public let media: [MBMediaItem]?
    public let releaseGroup: MBReleaseGroupSummaryItem?

    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case date
        case country
        case trackCount = "track-count"
        case artistCredit = "artist-credit"
        case media
        case releaseGroup = "release-group"
    }
}

private struct MBRecordingSearchResponse: Codable {
    public let recordings: [MBRecordingSearchItem]?
}

private struct MBRecordingSearchItem: Codable {
    public let id: String
    public let title: String
    public let length: Int?
    public let artistCredit: [MBArtistCreditItem]?
    public let releases: [MBReleaseItem]?

    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case length
        case artistCredit = "artist-credit"
        case releases
    }
}

private struct MBMediaItem: Codable {
    public let position: Int?
    public let title: String?
    public let trackCount: Int?
    public let tracks: [MBTrackItem]?

    public enum CodingKeys: String, CodingKey {
        case position
        case title
        case trackCount = "track-count"
        case tracks
    }
}

private struct MBTrackItem: Codable {
    public let id: String
    public let position: Int?
    public let number: String?
    public let title: String
    public let length: Int?
    public let recording: MBRecordingItem?
}

private struct MBRecordingItem: Codable {
    public let id: String
    public let title: String?
    public let length: Int?
}

private struct MBArtistCreditItem: Codable {
    public let name: String?
    public let artist: MBArtistItem?
}

private struct MBArtistItem: Codable {
    public let id: String?
    public let name: String?
}

private struct MBReleaseGroupSearchResponse: Codable {
    public let releaseGroups: [MBReleaseGroupSearchItem]?
    public enum CodingKeys: String, CodingKey {
        case releaseGroups = "release-groups"
    }
}

public struct MBReleaseGroupSearchItem: Codable, Sendable {
    public let id: String
    public let title: String
    public let primaryType: String?
    public let firstReleaseDate: String?
    public enum CodingKeys: String, CodingKey {
        case id, title
        case primaryType = "primary-type"
        case firstReleaseDate = "first-release-date"
    }

    nonisolated public init(
        id: String,
        title: String,
        primaryType: String?,
        firstReleaseDate: String?
    ) {
        self.id = id
        self.title = title
        self.primaryType = primaryType
        self.firstReleaseDate = firstReleaseDate
    }
}

private struct MBArtistSearchResponse: Codable {
    public let artists: [MBArtistSearchItem]?
}

private struct MBArtistSearchItem: Codable {
    public let id: String
    public let name: String
}
