//
//  LocalArtworkExtractor.swift
//  MSRU
//
//  Created for Audiophile Cover Art Extraction.
//

import Foundation
import AVFoundation
import AppFoundation
import MusicDomain

/// Discovers and extracts cover artwork for music tracks from directory files, embedded tags, or remote archive.
nonisolated public enum LocalArtworkExtractor {

    private static let commonImageFileNames: [String] = [
        "cover.jpg", "cover.jpeg", "cover.png",
        "folder.jpg", "folder.jpeg", "folder.png",
        "Folder.jpg", "Folder.jpeg", "Folder.png",
        "front.jpg", "front.jpeg", "front.png",
        "album.jpg", "album.jpeg", "album.png",
        "artwork.jpg", "artwork.jpeg", "artwork.png",
        "Artwork.jpg", "Artwork.png"
    ]

    /// Extracts artwork data for a given audio file URL by trying:
    /// 1. Same-folder image files (cover.jpg, folder.jpg, front.jpg, etc.)
    /// 2. Embedded metadata in the audio file (.commonIdentifierArtwork, FLAC Vorbis picture, DSF ID3 APIC)
    /// 3. Remote Cover Art Archive if releaseMBID / releaseGroupMBID is available
    /// 4. Remote MusicBrainz search fallback if artist and album/title are provided
    public static func extractArtwork(
        for fileURL: URL,
        releaseMBID: String? = nil,
        releaseGroupMBID: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        title: String? = nil
    ) async -> Data? {
        let folder = fileURL.deletingLastPathComponent()

        // 1. Probe directory for cover image files
        if let folderArtwork = extractFromDirectory(folderURL: folder) {
            return folderArtwork
        }

        // 2. Probe embedded metadata in audio file
        if let embedded = await extractFromAudioFile(url: fileURL) {
            return embedded
        }

        // 3. Remote Cover Art Archive fallback if releaseMBID or releaseGroupMBID is present
        if (releaseMBID != nil && !releaseMBID!.isEmpty) || (releaseGroupMBID != nil && !releaseGroupMBID!.isEmpty) {
            if let remoteData = await fetchRemoteCover(releaseMBID: releaseMBID, releaseGroupMBID: releaseGroupMBID) {
                return remoteData
            }
        }

        // 4. Remote MusicBrainz search fallback if artist is known
        if let artist, !artist.isEmpty {
            if let resolved = await resolveRemoteArtwork(artist: artist, album: album, title: title) {
                return resolved.data
            }
        }

        return nil
    }

    /// Probes directory for standard cover art files.
    public static func extractFromDirectory(folderURL: URL) -> Data? {
        let fm = FileManager.default
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        // Fast check known file names
        for name in commonImageFileNames {
            let candidateURL = folderURL.appendingPathComponent(name)
            if fm.fileExists(atPath: candidateURL.path),
               let data = try? Data(contentsOf: candidateURL),
               isValidImageData(data) {
                return data
            }
        }

        // Broad check: any jpg or png containing "cover" or "folder" or "front" in name
        if let files = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            for file in files {
                let ext = file.pathExtension.lowercased()
                if ext == "jpg" || ext == "jpeg" || ext == "png" {
                    let base = file.deletingPathExtension().lastPathComponent.lowercased()
                    if base.contains("cover") || base.contains("folder") || base.contains("front") || base.contains("artwork") {
                        if let data = try? Data(contentsOf: file), isValidImageData(data) {
                            return data
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Probes embedded artwork metadata from audio files (DSF, FLAC, MP3, MP4).
    public static func extractFromAudioFile(url: URL) async -> Data? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Fast path for DSF
        if url.pathExtension.lowercased() == "dsf" {
            if let dsfArt = DSFHeaderReader.readMetadata(from: url)?.artworkData, isValidImageData(dsfArt) {
                return dsfArt
            }
            return nil
        }

        let asset = AVURLAsset(url: url)
        var allItems: [AVMetadataItem] = []
        if let common = try? await asset.load(.commonMetadata) {
            allItems.append(contentsOf: common)
        }
        if let other = try? await asset.load(.metadata) {
            allItems.append(contentsOf: other)
        }

        // 1. Common artwork identifier
        let commonItems = AVMetadataItem.metadataItems(from: allItems, filteredByIdentifier: .commonIdentifierArtwork)
        for item in commonItems {
            if let data = try? await item.load(.dataValue), isValidImageData(data) {
                return data
            }
        }

        // 2. Picture / artwork items (FLAC vorb/METADATA_BLOCK_PICTURE, ID3 APIC, etc.)
        for item in allItems {
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            if idStr.contains("picture") || keyStr.contains("picture") || idStr.contains("artwork") || keyStr.contains("artwork") {
                if let data = try? await item.load(.dataValue), isValidImageData(data) {
                    return data
                }
            }
        }

        // 3. Fallback to any item containing valid image data
        for item in allItems {
            if let data = try? await item.load(.dataValue), isValidImageData(data) {
                return data
            }
        }

        return nil
    }

    /// Fetches front cover from Cover Art Archive for a release MBID or release-group MBID.
    public static func fetchRemoteCover(releaseMBID: String? = nil, releaseGroupMBID: String? = nil) async -> Data? {
        var urlStrings: [String] = []

        if let rg = releaseGroupMBID, !rg.isEmpty {
            urlStrings.append(contentsOf: [
                "https://coverartarchive.org/release-group/\(rg)/front-500",
                "https://coverartarchive.org/release-group/\(rg)/front-250",
                "https://coverartarchive.org/release-group/\(rg)/front"
            ])
        }

        if let rel = releaseMBID, !rel.isEmpty {
            urlStrings.append(contentsOf: [
                "https://coverartarchive.org/release/\(rel)/front-500",
                "https://coverartarchive.org/release/\(rel)/front-250",
                "https://coverartarchive.org/release/\(rel)/front"
            ])
        }

        for str in urlStrings {
            guard let url = URL(string: str) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               isValidImageData(data) {
                return data
            }
        }

        // If release-group direct front failed (e.g. 500/404), probe child releases under the release group
        if let rg = releaseGroupMBID, !rg.isEmpty {
            if let childCover = await fetchCoverFromChildReleases(releaseGroupMBID: rg) {
                return childCover
            }
        }

        return nil
    }

    private static func fetchCoverFromChildReleases(releaseGroupMBID: String) async -> Data? {
        guard let url = URL(string: "https://musicbrainz.org/ws/2/release?release-group=\(releaseGroupMBID)&fmt=json") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = json["releases"] as? [[String: Any]] else {
            return nil
        }

        for rel in releases.prefix(5) {
            if let rid = rel["id"] as? String {
                if let data = await fetchRemoteCover(releaseMBID: rid, releaseGroupMBID: nil) {
                    return data
                }
            }
        }
        return nil
    }

    /// Searches MusicBrainz for artist and album/title, returning downloaded image data and canonical metadata.
    public static func resolveRemoteArtwork(
        artist: String,
        album: String? = nil,
        title: String? = nil
    ) async -> (data: Data, canonicalAlbum: String?, releaseMBID: String?, releaseGroupMBID: String?)? {
        let cleanArt = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArt.isEmpty else { return nil }

        // Strategy 1: Search by album if available and not equal to artist name
        if let alb = album?.trimmingCharacters(in: .whitespacesAndNewlines),
           !alb.isEmpty,
           alb.lowercased() != cleanArt.lowercased() {
            if let releases = try? await MusicBrainzCatalogClient.shared.searchReleases(artist: cleanArt, album: alb) {
                for rel in releases {
                    if let imgData = await fetchRemoteCover(releaseMBID: rel.releaseMBID, releaseGroupMBID: rel.releaseGroupMBID) {
                        return (imgData, rel.title, rel.releaseMBID, rel.releaseGroupMBID)
                    }
                }
            }
        }

        // Strategy 2: Search by track title if album didn't match or was absent
        if let trkTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trkTitle.isEmpty {
            let recordings = await MusicBrainzCatalogClient.shared.searchRecordings(artist: cleanArt, title: trkTitle)
            for rec in recordings {
                let firstRelMBID = rec.releaseMBIDs.first
                if let imgData = await fetchRemoteCover(releaseMBID: firstRelMBID, releaseGroupMBID: rec.releaseGroupMBID) {
                    return (imgData, rec.albumTitle, firstRelMBID, rec.releaseGroupMBID)
                }
            }
        }

        // Strategy 3: Apple Music / iTunes Public Search API fallback (high-resolution official artwork)
        if let appleResult = await fetchAppleMusicCover(artist: cleanArt, album: album, title: title) {
            return (appleResult.data, appleResult.canonicalAlbum, nil, nil)
        }

        return nil
    }

    /// Searches Apple Music / iTunes Public Search API for high-resolution 600x600 artwork and canonical album metadata.
    public static func fetchAppleMusicCover(
        artist: String,
        album: String? = nil,
        title: String? = nil
    ) async -> (data: Data, canonicalAlbum: String?)? {
        let cleanArt = artist.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? artist

        // 1. Try Album Search
        if let alb = album?.trimmingCharacters(in: .whitespacesAndNewlines), !alb.isEmpty, alb.lowercased() != cleanArt.lowercased() {
            let cleanedAlb = MusicBrainzCatalogClient.cleanAlbumTitle(alb)
            let term = "\(cleanArt) \(cleanedAlb)"
            if let result = await queryITunes(term: term, entity: "album") {
                return result
            }
        }

        // 2. Try Song Search if album search didn't succeed or was missing
        if let trkTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trkTitle.isEmpty {
            var cleanedTitle = trkTitle
            if cleanedTitle.lowercased().hasPrefix(cleanArt.lowercased()) {
                cleanedTitle = cleanedTitle.dropFirst(cleanArt.count).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_"))
            }
            let term = "\(cleanArt) \(cleanedTitle)"
            if let result = await queryITunes(term: term, entity: "song") {
                return result
            }
        }

        return nil
    }

    private static func queryITunes(term: String, entity: String) async -> (data: Data, canonicalAlbum: String?)? {
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=\(entity)&limit=5") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("MSRU/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["results"] as? [[String: Any]] else {
            return nil
        }

        for item in items {
            let collection = item["collectionName"] as? String
            if let artUrlStr = item["artworkUrl100"] as? String {
                let hiResStr = artUrlStr.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
                    .replacingOccurrences(of: "100x100bb.png", with: "600x600bb.png")
                if let imgURL = URL(string: hiResStr) {
                    var imgReq = URLRequest(url: imgURL)
                    imgReq.timeoutInterval = 8
                    if let (imgData, imgResp) = try? await URLSession.shared.data(for: imgReq),
                       let imgHttp = imgResp as? HTTPURLResponse, (200...299).contains(imgHttp.statusCode),
                       isValidImageData(imgData) {
                        return (imgData, collection)
                    }
                }
            }
        }

        return nil
    }

    /// Validates raw data as image binary without importing platform-specific UI frameworks.
    public static func isValidImageData(_ data: Data) -> Bool {
        guard data.count > 32 else { return false }
        // Check for JPEG (0xFF, 0xD8, 0xFF) or PNG (0x89, 'P', 'N', 'G')
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return true
        }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return true
        }
        // GIF (GIF87a / GIF89a)
        if data.starts(with: [0x47, 0x49, 0x46]) {
            return true
        }
        // WEBP (RIFF....WEBP)
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count > 12 {
            let sub = data.subdata(in: 8..<12)
            if sub == Data([0x57, 0x45, 0x42, 0x50]) {
                return true
            }
        }
        return false
    }
}

// MARK: - Artwork File Exporter

/// Service for exporting companion artwork files (cover.jpg) alongside music files.
public struct ArtworkFileExporter: Sendable {
    public init() {}

    /// Exports cover artwork to the designated folder URL as `cover.jpg`.
    @discardableResult
    public static func exportCover(
        artworkData: Data?,
        to folderURL: URL,
        overwrite: Bool = false
    ) -> URL? {
        guard let data = artworkData, !data.isEmpty else { return nil }

        let coverURL = folderURL.appendingPathComponent("cover.jpg")
        if FileManager.default.fileExists(atPath: coverURL.path) && !overwrite {
            return coverURL
        }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try data.write(to: coverURL, options: .atomic)
            return coverURL
        } catch {
            return nil
        }
    }
}

