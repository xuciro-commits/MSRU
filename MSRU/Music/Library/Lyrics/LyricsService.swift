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

/// Multi-tier lyrics retrieval and caching service.
public actor LyricsService {
    public static let shared = LyricsService()

    private let cacheDirectory: URL
    private let client: LrcLibClient

    public init(client: LrcLibClient = .shared, cacheDirectory: URL? = nil) {
        self.client = client
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Lyrics", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.cacheDirectory = dir
        }
    }

    /// Resolves lyrics through a 4-tier pipeline:
    /// 1. Local companion .lrc file in the same folder as audio
    /// 2. Local persistent cache in Application Support
    /// 3. Embedded audio metadata lyrics (USLT / LYRICS)
    /// 4. Remote LRCLIB public API (no key needed)
    public func resolveLyrics(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        fileURL: URL? = nil
    ) async -> LrcDocument? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        // Tier 1: Local companion .lrc file
        if let fileURL {
            let hasAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

            let companionLrcURL = fileURL.deletingPathExtension().appendingPathExtension("lrc")
            if let content = try? String(contentsOf: companionLrcURL, encoding: .utf8), !content.isEmpty {
                let doc = LrcParser.parse(content)
                if !doc.lines.isEmpty || !doc.plainText.isEmpty {
                    return doc
                }
            }
        }

        // Tier 2: Local Application Support cache
        let cacheFile = cacheFileURL(title: cleanTitle, artist: cleanArtist)
        if FileManager.default.fileExists(atPath: cacheFile.path),
           let cachedContent = try? String(contentsOf: cacheFile, encoding: .utf8),
           !cachedContent.isEmpty {
            let doc = LrcParser.parse(cachedContent)
            if !doc.lines.isEmpty || !doc.plainText.isEmpty {
                return doc
            }
        }

        // Tier 3: Embedded audio metadata lyrics
        if let fileURL, let embedded = await extractEmbeddedLyrics(from: fileURL), !embedded.isEmpty {
            let doc = LrcParser.parse(embedded)
            if !doc.lines.isEmpty || !doc.plainText.isEmpty {
                try? embedded.write(to: cacheFile, atomically: true, encoding: .utf8)
                return doc
            }
        }

        // Tier 4: Remote LRCLIB lookup
        do {
            if let response = try await client.fetchLyrics(
                trackName: cleanTitle,
                artistName: cleanArtist,
                albumName: album,
                duration: duration
            ) {
                let lyricsText = (response.syncedLyrics != nil && !(response.syncedLyrics?.isEmpty ?? true))
                    ? response.syncedLyrics!
                    : (response.plainLyrics ?? "")

                if !lyricsText.isEmpty {
                    let doc = LrcParser.parse(lyricsText)
                    // Persist to local cache for instant offline playback
                    try? lyricsText.write(to: cacheFile, atomically: true, encoding: .utf8)
                    return doc
                }
            }
        } catch {
            print("Lyrics remote fetch error:", error.localizedDescription)
        }

        return nil
    }

    private func extractEmbeddedLyrics(from url: URL) async -> String? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }

        for item in metadata {
            if let str = try? await item.load(.stringValue) {
                if item.identifier == .commonIdentifierDescription ||
                   item.identifier?.rawValue.lowercased().contains("lyric") == true {
                    return str
                }
            }
        }
        return nil
    }

    private func cacheFileURL(title: String, artist: String) -> URL {
        let safeName = "\(artist) - \(title)"
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return cacheDirectory.appendingPathComponent("\(safeName).lrc")
    }
}

/// UI State Store coordinating synchronized lyrics with active audio playback.
@MainActor
@Observable
final class LyricsStore {
    static let shared = LyricsStore()

    private(set) var currentDocument: LrcDocument? = nil
    private(set) var activeLineIndex: Int? = nil
    private(set) var isLoading: Bool = false
    private(set) var loadedKey: String? = nil

    private var currentTask: Task<Void, Never>? = nil

    init() {}

    /// Keeps the lyrics state in lock-step with PlaybackController.
    func sync(with playback: PlaybackController) {
        guard playback.unifiedHasTrack, !playback.isLiveStream else {
            currentDocument = nil
            activeLineIndex = nil
            loadedKey = nil
            isLoading = false
            return
        }

        let key = "\(playback.unifiedTitle)::\(playback.unifiedSubtitle)"
        if loadedKey != key {
            loadLyrics(
                title: playback.unifiedTitle,
                artist: playback.unifiedSubtitle,
                album: playback.currentTrack?.album,
                duration: playback.duration,
                fileURL: playback.currentTrack?.fileURL
            )
        } else if let doc = currentDocument {
            let idx = doc.activeLineIndex(at: playback.currentTime)
            if idx != activeLineIndex {
                activeLineIndex = idx
            }
        }
    }

    func loadLyrics(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        fileURL: URL? = nil
    ) {
        let key = "\(title)::\(artist)"
        loadedKey = key
        isLoading = true
        activeLineIndex = nil

        currentTask?.cancel()
        currentTask = Task { @MainActor in
            let doc = await LyricsService.shared.resolveLyrics(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                fileURL: fileURL
            )
            guard !Task.isCancelled else { return }
            if self.loadedKey == key {
                self.currentDocument = doc
                self.isLoading = false
            }
        }
    }

    /// User tapped a lyric line to seek playback.
    func seek(to line: LrcLine, playback: PlaybackController) {
        playback.seek(to: line.timestamp)
    }
}
