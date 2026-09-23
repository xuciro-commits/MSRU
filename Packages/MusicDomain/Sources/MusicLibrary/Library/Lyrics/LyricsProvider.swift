//
//  LyricsProvider.swift
//  MSRU
//
//  Multi-tier lyrics provider protocol and built-in implementations.
//  Providers are evaluated in priority order; the first non-nil result wins.
//

import Foundation
import AVFoundation
import AppFoundation
import MediaLibrary
import SubsonicKit
import CryptoKit
import MusicDomain

// MARK: - Lyrics Query Context

/// Aggregates all known identity signals for the currently playing track,
/// enabling each lyrics provider to pick the best matching strategy.
nonisolated public struct LyricsQueryContext: Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval?
    public let fileURL: URL?
    /// MusicBrainz Recording MBID resolved via acoustic fingerprint.
    public let recordingMBID: String?
    /// Subsonic remote song ID (only present when source is a Subsonic/NAS server).
    public let subsonicSongID: String?
    /// Subsonic server identifier matching the registered library provider.
    public let sourceID: String?

    public init(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        fileURL: URL? = nil,
        recordingMBID: String? = nil,
        subsonicSongID: String? = nil,
        sourceID: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.fileURL = fileURL
        self.recordingMBID = recordingMBID
        self.subsonicSongID = subsonicSongID
        self.sourceID = sourceID
    }
}

// MARK: - Lyrics Provider Protocol

/// A source capable of fetching lyrics text (LRC synced or plain) for a given track.
nonisolated public protocol LyricsProvider: Sendable {
    var providerName: String { get }

    /// Attempts to fetch lyrics for the given context.
    /// Returns raw lyrics text (LRC format preferred) or nil if unavailable.
    func fetchLyrics(context: LyricsQueryContext) async throws -> String?
}

// MARK: - Provider 1: Local Companion .lrc File

/// Reads a `.lrc` sidecar file located alongside the audio file.
nonisolated public struct LocalCompanionLyricsProvider: LyricsProvider {
    public let providerName = "Local Companion .lrc"

    public init() {}

    public func fetchLyrics(context: LyricsQueryContext) async throws -> String? {
        guard let fileURL = context.fileURL else { return nil }

        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let companionLrcURL = fileURL.deletingPathExtension().appendingPathExtension("lrc")
        guard let content = try? String(contentsOf: companionLrcURL, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return content
    }
}

// MARK: - Provider 2: Local Persistent Cache

/// Reads from the Application Support lyrics cache directory.
nonisolated public struct CachedLyricsProvider: LyricsProvider {
    public let providerName = "Local Cache"
    private let cacheDirectory: URL

    public init(cacheDirectory: URL? = nil) {
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

    public func fetchLyrics(context: LyricsQueryContext) async throws -> String? {
        let cacheFile = Self.cacheFileURL(context: context, cacheDirectory: cacheDirectory)
        guard FileManager.default.fileExists(atPath: cacheFile.path),
              let content = try? String(contentsOf: cacheFile, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return content
    }

    /// Stable cache file URL for a given title+artist pair.
    public static func cacheFileURL(title: String, artist: String, cacheDirectory: URL) -> URL {
        let safeName = "\(artist) - \(title)"
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return cacheDirectory.appendingPathComponent("\(safeName).lrc")
    }

    /// Keeps distinct remote songs apart even when their display metadata matches.
    public static func cacheFileURL(context: LyricsQueryContext, cacheDirectory: URL) -> URL {
        if let sourceID = context.sourceID, let songID = context.subsonicSongID {
            let identity = "\(sourceID):\(songID)"
            let digest = SHA256.hash(data: Data(identity.utf8))
                .map { String(format: "%02x", $0) }.joined()
            return cacheDirectory.appendingPathComponent("subsonic-\(digest).lrc")
        }
        return cacheFileURL(title: context.title, artist: context.artist, cacheDirectory: cacheDirectory)
    }
}

// MARK: - Provider 3: Embedded Audio Tag Lyrics

/// Extracts lyrics embedded in audio file metadata (USLT / LYRICS Vorbis Comment).
nonisolated public struct EmbeddedTagLyricsProvider: LyricsProvider {
    public let providerName = "Embedded Audio Tags"

    public init() {}

    public func fetchLyrics(context: LyricsQueryContext) async throws -> String? {
        guard let fileURL = context.fileURL else { return nil }

        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: fileURL)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }

        for item in metadata {
            if let str = try? await item.load(.stringValue), !str.isEmpty {
                if item.identifier?.rawValue.lowercased().contains("lyric") == true {
                    return str
                }
            }
        }

        // Also check format-specific metadata (Vorbis LYRICS tag)
        if let formatMetadata = try? await asset.load(.metadata) {
            for item in formatMetadata {
                if let key = item.identifier?.rawValue.lowercased(),
                   key.contains("lyric") || key.contains("uslt"),
                   let str = try? await item.load(.stringValue), !str.isEmpty {
                    return str
                }
            }
        }

        return nil
    }
}

// MARK: - Provider 4: LRCLIB Public API

/// Queries the free, open-source LRCLIB synchronized lyrics database.
nonisolated public struct LrcLibLyricsProvider: LyricsProvider {
    public let providerName = "LRCLIB"
    private let client: LrcLibClient

    public init(client: LrcLibClient = .shared) {
        self.client = client
    }

    public func fetchLyrics(context: LyricsQueryContext) async throws -> String? {
        let cleanTitle = context.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = context.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        let response = try await client.fetchLyrics(
            trackName: cleanTitle,
            artistName: cleanArtist,
            albumName: context.album,
            duration: context.duration
        )

        guard let response else { return nil }

        // Prefer synced lyrics over plain
        if let synced = response.syncedLyrics, !synced.isEmpty {
            return synced
        }
        if let plain = response.plainLyrics, !plain.isEmpty {
            return plain
        }

        return nil
    }
}

// MARK: - Provider 5: OpenSubsonic Lyrics

/// Uses the exact remote song identity and its source's authenticated client.
nonisolated public struct SubsonicLyricsProvider: LyricsProvider {
    public let providerName = "OpenSubsonic"
    private let registry: LibraryProviderRegistry

    public init(registry: LibraryProviderRegistry = .shared) {
        self.registry = registry
    }

    public func fetchLyrics(context: LyricsQueryContext) async throws -> String? {
        guard let songID = context.subsonicSongID, !songID.isEmpty,
              let sourceID = context.sourceID, !sourceID.isEmpty,
              let provider = registry.provider(for: LibrarySourceID(sourceID)) as? SubsonicLibraryProvider else {
            return nil
        }
        return try await provider.client.getLyricsBySongId(id: songID)?.toLrcText()
    }
}
