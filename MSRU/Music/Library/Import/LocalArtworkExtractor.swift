//
//  LocalArtworkExtractor.swift
//  MSRU
//
//  Created for Audiophile Cover Art Extraction.
//

import Foundation
import AVFoundation

/// Discovers and extracts cover artwork for music tracks from directory files, embedded tags, or remote archive.
public enum LocalArtworkExtractor {

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
    /// 2. Embedded metadata in the audio file (.commonIdentifierArtwork)
    /// 3. Remote Cover Art Archive if releaseMBID is available
    public static func extractArtwork(for fileURL: URL, releaseMBID: String? = nil) async -> Data? {
        let folder = fileURL.deletingLastPathComponent()

        // 1. Probe directory for cover image files
        if let folderArtwork = extractFromDirectory(folderURL: folder) {
            return folderArtwork
        }

        // 2. Probe embedded metadata in audio file
        if let embedded = await extractFromAudioFile(url: fileURL) {
            return embedded
        }

        // 3. Remote Cover Art Archive fallback if releaseMBID is present
        if let releaseMBID = releaseMBID, !releaseMBID.isEmpty {
            if let remoteData = await fetchRemoteCover(releaseMBID: releaseMBID) {
                return remoteData
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

    /// Probes embedded artwork metadata from AVURLAsset.
    public static func extractFromAudioFile(url: URL) async -> Data? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }

        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
        guard let item = items.first else { return nil }

        if let data = try? await item.load(.dataValue), isValidImageData(data) {
            return data
        }
        return nil
    }

    /// Fetches front cover from Cover Art Archive for a release MBID.
    public static func fetchRemoteCover(releaseMBID: String) async -> Data? {
        let urlStrings = [
            "https://coverartarchive.org/release/\(releaseMBID)/front-500",
            "https://coverartarchive.org/release/\(releaseMBID)/front-250",
            "https://coverartarchive.org/release/\(releaseMBID)/front"
        ]

        for str in urlStrings {
            guard let url = URL(string: str) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.setValue("MSRU/0.1 (local-development)", forHTTPHeaderField: "User-Agent")

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               isValidImageData(data) {
                return data
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
