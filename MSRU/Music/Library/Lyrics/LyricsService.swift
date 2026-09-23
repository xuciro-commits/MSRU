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

    nonisolated let cacheDirectory: URL
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

/// UI State Store coordinating synchronized lyrics with active audio playback and real-time tuning.
@MainActor
@Observable
final class LyricsStore {
    static let shared = LyricsStore()

    private(set) var currentDocument: LrcDocument? = nil
    private(set) var activeLineIndex: Int? = nil
    private(set) var isLoading: Bool = false
    private(set) var loadedKey: String? = nil
    private(set) var timeOffset: TimeInterval = 0.0
    private(set) var currentFileURL: URL? = nil
    private(set) var currentTitle: String = ""
    private(set) var currentArtist: String = ""
    private var currentContext: LyricsQueryContext?
    private(set) var isSavingTuning: Bool = false
    private(set) var lastSaveMessage: String? = nil

    private var currentTask: Task<Void, Never>? = nil

    init() {}

    /// Keeps the lyrics state in lock-step with PlaybackController.
    func sync(with playback: PlaybackController) {
        guard playback.unifiedHasTrack, !playback.isLiveStream else {
            currentTask?.cancel()
            currentDocument = nil
            activeLineIndex = nil
            loadedKey = nil
            isLoading = false
            timeOffset = 0.0
            currentFileURL = nil
            currentContext = nil
            return
        }

        let key = playback.currentItem?.id ?? "\(playback.unifiedTitle)::\(playback.unifiedSubtitle)"
        if loadedKey != key {
            // Build identity context; MBID will be resolved asynchronously inside loadLyrics
            let context = LyricsQueryContext(
                title: playback.unifiedTitle,
                artist: playback.unifiedSubtitle,
                album: playback.currentTrack?.album ?? playback.currentItem?.album,
                duration: playback.duration > 0 ? playback.duration : nil,
                fileURL: playback.currentTrack?.fileURL,
                recordingMBID: playback.currentRecordingMBID,
                subsonicSongID: playback.currentSubsonicSongID,
                sourceID: playback.currentItem?.subsonicServerID
            )
            loadLyrics(context: context, playback: playback, identityKey: key)
        } else {
            updateActiveLine(currentTime: playback.currentTime)
        }
    }

    func loadLyrics(context: LyricsQueryContext, playback: PlaybackController? = nil, identityKey: String? = nil) {
        let key = identityKey ?? "\(context.title)::\(context.artist)"
        loadedKey = key
        isLoading = true
        currentDocument = nil
        activeLineIndex = nil
        timeOffset = 0.0
        currentFileURL = context.fileURL
        currentContext = context
        currentTitle = context.title
        currentArtist = context.artist
        lastSaveMessage = nil

        currentTask?.cancel()
        currentTask = Task { @MainActor in
            // Resolve recording MBID asynchronously if we have a local file
            var enrichedContext = context
            if let fileURL = context.fileURL, context.recordingMBID == nil {
                let registry = LocalFingerprintRegistry.shared
                if let fp = await registry.cachedFingerprint(for: fileURL),
                   let record = await registry.lookup(fingerprint: fp, duration: 0, tolerance: .infinity),
                   let mbid = record.recordingMBID, !mbid.isEmpty {
                    enrichedContext = LyricsQueryContext(
                        title: context.title,
                        artist: context.artist,
                        album: context.album,
                        duration: context.duration,
                        fileURL: context.fileURL,
                        recordingMBID: mbid,
                        subsonicSongID: context.subsonicSongID,
                        sourceID: context.sourceID
                    )
                    if self.loadedKey == key {
                        self.currentContext = enrichedContext
                    }
                    // Also update playback controller's cached MBID
                    if !Task.isCancelled, self.loadedKey == key {
                        playback?.currentRecordingMBID = mbid
                    }
                }
            }

            guard !Task.isCancelled else { return }
            let doc = await LyricsService.shared.resolveLyrics(context: enrichedContext)
            guard !Task.isCancelled else { return }
            if self.loadedKey == key {
                self.currentDocument = doc
                self.isLoading = false
            }
        }
    }

    /// Backward-compatible convenience overload.
    func loadLyrics(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        fileURL: URL? = nil
    ) {
        let context = LyricsQueryContext(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            fileURL: fileURL
        )
        loadLyrics(context: context)
    }

    /// Directly injects a document into the store for testing.
    func loadDocumentForTesting(_ doc: LrcDocument, fileURL: URL? = nil, title: String = "", artist: String = "") {
        currentDocument = doc
        currentFileURL = fileURL
        currentTitle = title
        currentArtist = artist
        currentContext = LyricsQueryContext(title: title, artist: artist, fileURL: fileURL)
        isLoading = false
        timeOffset = 0.0
        lastSaveMessage = nil
    }

    /// User tapped a lyric line to seek playback.
    func seek(to line: LrcLine, playback: PlaybackController) {
        let targetTime = max(0, line.timestamp - timeOffset)
        playback.seek(to: targetTime)
    }

    /// Adjusts playback sync offset by delta (+0.5s leads/advances lyrics, -0.5s delays lyrics).
    func adjustOffset(by delta: TimeInterval, playback: PlaybackController) {
        lastSaveMessage = nil
        timeOffset += delta
        timeOffset = (timeOffset * 10).rounded() / 10
        updateActiveLine(currentTime: playback.currentTime)
    }

    /// Resets sync offset back to 0.0s.
    func resetOffset(playback: PlaybackController) {
        lastSaveMessage = nil
        timeOffset = 0.0
        updateActiveLine(currentTime: playback.currentTime)
    }

    private func updateActiveLine(currentTime: TimeInterval) {
        guard let doc = currentDocument, doc.isSynced else { return }
        let effectiveTime = max(0, currentTime + timeOffset)
        let idx = doc.activeLineIndex(at: effectiveTime)
        if idx != activeLineIndex {
            activeLineIndex = idx
        }
    }

    /// Writes the calibrated lyrics permanently to companion .lrc sidecar and/or embedded audio tags.
    func saveTunedLyrics(
        audioURL: URL? = nil,
        writeSidecar: Bool = true,
        embedInAudio: Bool = true
    ) async throws {
        guard let doc = currentDocument, doc.isSynced else { return }
        isSavingTuning = true
        defer { isSavingTuning = false }

        let targetURL = audioURL ?? currentFileURL
        let adjustedDoc = doc.applyingOffset(-timeOffset)
        let lrcContent = adjustedDoc.formatLrc()

        if let targetURL {
            let tagWriter = AudioTagWriter()
            _ = try await tagWriter.writeLyrics(
                to: targetURL,
                lrcContent: lrcContent,
                writeSidecar: writeSidecar,
                embedInAudio: embedInAudio
            )
        }

        if let context = currentContext, !currentTitle.isEmpty, !currentArtist.isEmpty {
            let cacheFile = CachedLyricsProvider.cacheFileURL(
                context: context,
                cacheDirectory: LyricsService.shared.cacheDirectory
            )
            try? lrcContent.write(to: cacheFile, atomically: true, encoding: .utf8)
        }

        self.currentDocument = adjustedDoc
        self.timeOffset = 0.0
        self.lastSaveMessage = "Saved"
    }
}
