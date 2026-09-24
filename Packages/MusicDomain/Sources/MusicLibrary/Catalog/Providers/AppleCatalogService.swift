//
//  AppleCatalogService.swift
//  MSRU
//
//  Created for Authoritative Apple Music & iTunes Catalog Resolution.
//

import Foundation
import MusicDomain

// MARK: - Models

nonisolated public struct AppleAlbumMatch: Sendable, Equatable, Identifiable {
    public var id: Int { collectionId }
    public let collectionId: Int
    public let title: String
    public let artist: String
    public let releaseDate: String?
    public let trackCount: Int
    public let genre: String?
    public let artworkURL: URL?

    public init(
        collectionId: Int,
        title: String,
        artist: String,
        releaseDate: String? = nil,
        trackCount: Int = 0,
        genre: String? = nil,
        artworkURL: URL? = nil
    ) {
        self.collectionId = collectionId
        self.title = title
        self.artist = artist
        self.releaseDate = releaseDate
        self.trackCount = trackCount
        self.genre = genre
        self.artworkURL = artworkURL
    }
}

nonisolated public struct AppleTrackMatch: Sendable, Equatable, Identifiable {
    public var id: Int { trackId }
    public let trackId: Int
    public let collectionId: Int
    public let trackNumber: Int
    public let discNumber: Int
    public let title: String
    public let artist: String
    public let duration: TimeInterval
    public let previewURL: URL?

    public init(
        trackId: Int,
        collectionId: Int,
        trackNumber: Int,
        discNumber: Int = 1,
        title: String,
        artist: String,
        duration: TimeInterval,
        previewURL: URL? = nil
    ) {
        self.trackId = trackId
        self.collectionId = collectionId
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.title = title
        self.artist = artist
        self.duration = duration
        self.previewURL = previewURL
    }
}

// MARK: - Service Actor

/// Thread-safe client for querying Apple's canonical catalog (iTunes API + Apple Music storefronts)
/// and aligning anomalous local albums with official tracklists and 1400x1400 artwork.
public actor AppleCatalogService: Sendable {

    public static let shared = AppleCatalogService()

    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Public API

    /// Searches Apple Catalog for an album by artist and title.
    public func searchAlbums(
        artist: String? = nil,
        album: String,
        storefronts: [String] = ["cn", "hk", "us"]
    ) async -> [AppleAlbumMatch] {
        let cleanAlb = MetadataSanitizer.cleanAlbumTitle(album, artist: artist)
        let cleanArt = artist.map { MetadataSanitizer.cleanArtistName($0) } ?? ""

        var termsToTry: [String] = []
        if !cleanArt.isEmpty && cleanArt != "Unknown Artist" {
            termsToTry.append("\(cleanArt) \(cleanAlb)")
        }
        termsToTry.append(cleanAlb)

        for storefront in storefronts {
            for term in termsToTry {
                let matches = await queryAlbumEndpoint(term: term, country: storefront)
                if !matches.isEmpty {
                    return matches
                }
            }
        }

        return []
    }

    /// Fetches the complete official tracklist for an Apple collection ID.
    public func fetchAlbumTracks(collectionId: Int, country: String? = nil) async -> [AppleTrackMatch] {
        var urlStr = "https://itunes.apple.com/lookup?id=\(collectionId)&entity=song"
        if let country {
            urlStr += "&country=\(country)"
        }
        guard let url = URL(string: urlStr) else { return [] }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        var tracks: [AppleTrackMatch] = []
        for item in results {
            guard let wrapper = item["wrapperType"] as? String, wrapper == "track",
                  let trackId = item["trackId"] as? Int,
                  let trackName = item["trackName"] as? String,
                  let trkNo = item["trackNumber"] as? Int else {
                continue
            }
            let discNo = item["discNumber"] as? Int ?? 1
            let collId = item["collectionId"] as? Int ?? collectionId
            let artistName = item["artistName"] as? String ?? ""
            let millis = item["trackTimeMillis"] as? Double ?? 0
            let duration = millis / 1000.0
            let previewStr = item["previewUrl"] as? String
            let previewURL = previewStr.flatMap { URL(string: $0) }

            tracks.append(AppleTrackMatch(
                trackId: trackId,
                collectionId: collId,
                trackNumber: trkNo,
                discNumber: discNo,
                title: trackName,
                artist: artistName,
                duration: duration,
                previewURL: previewURL
            ))
        }

        return tracks.sorted {
            if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
            return $0.trackNumber < $1.trackNumber
        }
    }

    /// Fetches album details along with tracks by collectionId.
    public func lookupAlbumDetails(collectionId: Int, country: String? = nil) async -> (album: AppleAlbumMatch, tracks: [AppleTrackMatch])? {
        var urlStr = "https://itunes.apple.com/lookup?id=\(collectionId)&entity=song"
        if let country {
            urlStr += "&country=\(country)"
        }
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.setValue("MSRU/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]], !results.isEmpty else {
            return nil
        }

        var foundAlbum: AppleAlbumMatch?
        var tracks: [AppleTrackMatch] = []

        for item in results {
            let wrapper = item["wrapperType"] as? String
            if wrapper == "collection" {
                let collId = item["collectionId"] as? Int ?? collectionId
                let collName = item["collectionName"] as? String ?? ""
                let artistName = item["artistName"] as? String ?? ""
                let relDate = item["releaseDate"] as? String
                let trkCount = item["trackCount"] as? Int ?? 0
                let genre = item["primaryGenreName"] as? String

                var artURL: URL? = nil
                if let art100 = item["artworkUrl100"] as? String {
                    let hiRes = art100.replacingOccurrences(of: "100x100bb.jpg", with: "1400x1400bb.jpg")
                        .replacingOccurrences(of: "100x100bb.png", with: "1400x1400bb.png")
                    artURL = URL(string: hiRes)
                }

                foundAlbum = AppleAlbumMatch(
                    collectionId: collId,
                    title: collName,
                    artist: artistName,
                    releaseDate: relDate,
                    trackCount: trkCount,
                    genre: genre,
                    artworkURL: artURL
                )
            } else if wrapper == "track" {
                guard let trackId = item["trackId"] as? Int,
                      let trackName = item["trackName"] as? String,
                      let trkNo = item["trackNumber"] as? Int else {
                    continue
                }
                let discNo = item["discNumber"] as? Int ?? 1
                let collId = item["collectionId"] as? Int ?? collectionId
                let artistName = item["artistName"] as? String ?? ""
                let millis = item["trackTimeMillis"] as? Double ?? 0
                tracks.append(AppleTrackMatch(
                    trackId: trackId,
                    collectionId: collId,
                    trackNumber: trkNo,
                    discNumber: discNo,
                    title: trackName,
                    artist: artistName,
                    duration: millis / 1000.0
                ))
            }
        }

        guard let album = foundAlbum, !tracks.isEmpty else { return nil }
        let sortedTracks = tracks.sorted {
            if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
            return $0.trackNumber < $1.trackNumber
        }
        return (album, sortedTracks)
    }

    /// Searches for a single track in Apple Catalog by artist and title.
    public func searchSong(artist: String, title: String, storefront: String = "cn") async -> AppleTrackMatch? {
        let cleanTitle = MetadataSanitizer.cleanTrackTitle(title, artist: artist).title
        let cleanArt = MetadataSanitizer.cleanArtistName(artist)
        let term = "\(cleanArt) \(cleanTitle)"

        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=3&country=\(storefront)") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 8.0)
        request.setValue("MSRU/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let trackId = first["trackId"] as? Int,
              let trackName = first["trackName"] as? String,
              let trkNo = first["trackNumber"] as? Int else {
            return nil
        }

        let discNo = first["discNumber"] as? Int ?? 1
        let collId = first["collectionId"] as? Int ?? 0
        let artistName = first["artistName"] as? String ?? cleanArt
        let millis = first["trackTimeMillis"] as? Double ?? 0

        return AppleTrackMatch(
            trackId: trackId,
            collectionId: collId,
            trackNumber: trkNo,
            discNumber: discNo,
            title: trackName,
            artist: artistName,
            duration: millis / 1000.0
        )
    }

    /// Downloads high-resolution artwork bytes (1400x1400 or 600x600).
    public func fetchArtworkData(from url: URL) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 12.0)
        req.setValue("MSRU/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: req),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              LocalArtworkExtractor.isValidImageData(data) else {
            return nil
        }
        return data
    }

    /// Aligns a set of local tracks from an album against Apple's official tracklist.
    /// Returns the updated LocalTracks with authoritative titles, track numbers, and artwork references.
    public func alignAlbum(
        artistHint: String,
        albumHint: String,
        localTracks: [LocalTrack]
    ) async -> (updatedTracks: [LocalTrack], canonicalAlbum: String?, artworkReference: String?)? {
        guard !localTracks.isEmpty else { return nil }

        var resolvedAlbum: AppleAlbumMatch? = nil
        var appleTracks: [AppleTrackMatch] = []

        if !albumHint.isEmpty && albumHint != "Unknown Album" {
            let albums = await searchAlbums(artist: artistHint, album: albumHint)
            if let best = albums.first {
                resolvedAlbum = best
                appleTracks = await fetchAlbumTracks(collectionId: best.collectionId)
            }
        }

        // Fallback: If album search yielded nothing or albumHint was missing, search for non-anomalous tracks to discover album
        if resolvedAlbum == nil || appleTracks.isEmpty {
            let candidateSongs = localTracks.filter { !MetadataSanitizer.isAnomalousTitle($0.title) }
            for cand in candidateSongs.prefix(3) {
                if let songMatch = await searchSong(artist: artistHint, title: cand.title), songMatch.collectionId > 0 {
                    if let details = await lookupAlbumDetails(collectionId: songMatch.collectionId) {
                        resolvedAlbum = details.album
                        appleTracks = details.tracks
                        break
                    }
                }
            }
        }

        guard let bestAlbum = resolvedAlbum, !appleTracks.isEmpty else { return nil }

        // Fetch official high-res artwork if available
        var artRef: String? = nil
        if let artURL = bestAlbum.artworkURL,
           let artData = await fetchArtworkData(from: artURL) {
            artRef = LocalArtworkStorage.shared.storeArtwork(artData)
        }

        let appleByTrackNo = Dictionary(uniqueKeysWithValues: appleTracks.map { ($0.trackNumber, $0) })
        var alignedList: [LocalTrack] = []

        for track in localTracks {
            var newTitle = track.title
            var newTrackNo = track.trackNumber
            var newArtist = track.artist

            let (cleanT, detectedNo, isAnom) = MetadataSanitizer.cleanTrackTitle(track.title, artist: track.artist)
            if newTrackNo == nil || newTrackNo == 0 {
                newTrackNo = detectedNo
            }

            var matchedApple: AppleTrackMatch? = nil

            // 1. Match by Track Number
            if let trkNo = newTrackNo, let candidate = appleByTrackNo[trkNo] {
                // If track duration is available, verify tolerance within 10 seconds
                if track.duration > 0 && candidate.duration > 0 {
                    if abs(track.duration - candidate.duration) <= 10.0 {
                        matchedApple = candidate
                    } else if isAnom {
                        // For placeholder tracks like Track05, track number match is definitive
                        matchedApple = candidate
                    }
                } else {
                    matchedApple = candidate
                }
            }

            // 2. Fallback: Match by exact duration tolerance (± 2.5 seconds)
            if matchedApple == nil && track.duration > 0 {
                matchedApple = appleTracks.first { abs($0.duration - track.duration) <= 2.5 }
            }

            if let apple = matchedApple {
                newTitle = apple.title
                newTrackNo = apple.trackNumber
                if newArtist == "Unknown Artist" || newArtist.isEmpty {
                    newArtist = apple.artist
                }
            } else if !isAnom {
                newTitle = cleanT
            }

            let finalArtRef = track.artworkReference ?? artRef

            alignedList.append(LocalTrack(
                fileURL: track.fileURL,
                title: newTitle,
                artist: newArtist,
                album: bestAlbum.title,
                duration: track.duration,
                artworkReference: finalArtRef,
                trackNumber: newTrackNo,
                year: Int(bestAlbum.releaseDate?.prefix(4) ?? "") ?? track.year
            ))
        }

        return (alignedList, bestAlbum.title, artRef)
    }

    // MARK: - Private Helpers

    private func queryAlbumEndpoint(term: String, country: String) async -> [AppleAlbumMatch] {
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=album&limit=5&country=\(country)") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: 8.0)
        request.setValue("MSRU/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        var matches: [AppleAlbumMatch] = []
        for item in results {
            guard let collId = item["collectionId"] as? Int,
                  let collName = item["collectionName"] as? String else {
                continue
            }
            let artistName = item["artistName"] as? String ?? ""
            let relDate = item["releaseDate"] as? String
            let trkCount = item["trackCount"] as? Int ?? 0
            let genre = item["primaryGenreName"] as? String

            var artURL: URL? = nil
            if let art100 = item["artworkUrl100"] as? String {
                let hiRes = art100.replacingOccurrences(of: "100x100bb.jpg", with: "1400x1400bb.jpg")
                    .replacingOccurrences(of: "100x100bb.png", with: "1400x1400bb.png")
                artURL = URL(string: hiRes)
            }

            matches.append(AppleAlbumMatch(
                collectionId: collId,
                title: collName,
                artist: artistName,
                releaseDate: relDate,
                trackCount: trkCount,
                genre: genre,
                artworkURL: artURL
            ))
        }

        return matches
    }
}
