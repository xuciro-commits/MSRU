//
//  LyricsStore.swift
//  MSRU
//
//  Synchronized lyrics state kept in lock-step with playback.
//

import Foundation
import Observation
import AppFoundation
import MusicDomain
import MusicLibrary

/// UI State Store coordinating synchronized lyrics with active audio playback and real-time tuning.
@MainActor
@Observable
public final class LyricsStore {
    public static let shared = LyricsStore()

    public private(set) var currentDocument: LrcDocument? = nil
    public private(set) var activeLineIndex: Int? = nil
    public private(set) var isLoading: Bool = false
    public private(set) var loadedKey: String? = nil
    public private(set) var timeOffset: TimeInterval = 0.0
    public private(set) var currentFileURL: URL? = nil
    public private(set) var currentTitle: String = ""
    public private(set) var currentArtist: String = ""
    private var currentContext: LyricsQueryContext?
    public private(set) var isSavingTuning: Bool = false
    public private(set) var lastSaveMessage: String? = nil

    private var currentTask: Task<Void, Never>? = nil

    public init() {}

    /// Keeps the lyrics state in lock-step with PlaybackController.
    public func sync(with playback: PlaybackController) {
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

    /// Forces re-fetching lyrics for the currently playing track.
    public func reload(playback: PlaybackController) {
        loadedKey = nil
        sync(with: playback)
    }

    public func loadLyrics(context: LyricsQueryContext, playback: PlaybackController? = nil, identityKey: String? = nil) {
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
    public func loadLyrics(
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
    public func loadDocumentForTesting(_ doc: LrcDocument, fileURL: URL? = nil, title: String = "", artist: String = "") {
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
    public func seek(to line: LrcLine, playback: PlaybackController) {
        let targetTime = max(0, line.timestamp - timeOffset)
        playback.seek(to: targetTime)
    }

    /// Adjusts playback sync offset by delta (+0.5s leads/advances lyrics, -0.5s delays lyrics).
    public func adjustOffset(by delta: TimeInterval, playback: PlaybackController) {
        lastSaveMessage = nil
        timeOffset += delta
        timeOffset = (timeOffset * 10).rounded() / 10
        updateActiveLine(currentTime: playback.currentTime)
    }

    /// Resets sync offset back to 0.0s.
    public func resetOffset(playback: PlaybackController) {
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
    public func saveTunedLyrics(
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
