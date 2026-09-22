//
//  AudioFingerprintService.swift
//  MSRU
//
//  Created for Dedicated Background Acoustic Fingerprint Orchestration.
//

import Foundation
import AppFoundation

// MARK: - Audio File Signature

/// A lightweight heuristic signature of an audio file on disk used exclusively
/// for cache-invalidation decisions.
///
/// Note: This signature reflects physical file metadata (size, modification time, canonical path)
/// and serves as a fast validation heuristic; it does NOT assert cryptographic proof of content identity.
nonisolated public struct AudioFileSignature: Hashable, Sendable, Codable {

    public static let currentSchemaVersion = 1

    public let canonicalPath: String
    public let fileSize: Int64
    public let modificationTime: TimeInterval
    public let schemaVersion: Int

    public init(
        canonicalPath: String,
        fileSize: Int64,
        modificationTime: TimeInterval,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.canonicalPath = canonicalPath
        self.fileSize = fileSize
        self.modificationTime = modificationTime
        self.schemaVersion = schemaVersion
    }

    /// Creates a signature by inspecting the attributes of the item at the given file URL.
    public init?(fileURL: URL) {
        let canonical = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: canonical),
              let size = attrs[.size] as? Int64,
              let mdate = attrs[.modificationDate] as? Date else {
            return nil
        }
        self.canonicalPath = canonical
        self.fileSize = size
        self.modificationTime = mdate.timeIntervalSince1970
        self.schemaVersion = Self.currentSchemaVersion
    }

    /// Fast validation check against the current filesystem state of the given URL.
    public func matches(fileURL: URL, tolerance: TimeInterval = 1.0) -> Bool {
        guard let current = AudioFileSignature(fileURL: fileURL) else { return false }
        return current.canonicalPath == self.canonicalPath &&
               current.fileSize == self.fileSize &&
               abs(current.modificationTime - self.modificationTime) < tolerance
    }
}

// MARK: - Batch Result

/// Summary metrics returned upon completion of a batch fingerprint indexing run.
nonisolated public struct FingerprintBatchResult: Sendable, Equatable {
    public let totalReceived: Int
    public let skippedCachedCount: Int
    public let newlyComputedCount: Int
    public let persistenceWrites: Int

    public var extractedCount: Int { newlyComputedCount }

    public init(
        totalReceived: Int,
        skippedCachedCount: Int,
        newlyComputedCount: Int,
        persistenceWrites: Int
    ) {
        self.totalReceived = totalReceived
        self.skippedCachedCount = skippedCachedCount
        self.newlyComputedCount = newlyComputedCount
        self.persistenceWrites = persistenceWrites
    }
}

// MARK: - Fingerprint Service

/// Dedicated background actor acting as the unique global owner of exact audio signature
/// extraction, heuristic caching, in-flight task deduplication, and batched registry persistence.
///
/// Role: **Exactness Evidence** (Local Dedupe, File Move/Rename Tracking)
public actor AudioFingerprintService: Sendable {

    public static let shared = AudioFingerprintService()

    private let fingerprinter: any AudioFingerprinting
    private let registry: LocalFingerprintRegistry
    private var inFlightTasks: [String: Task<AudioFingerprint, Error>] = [:]

    public private(set) var totalReceivedCount: Int = 0
    public private(set) var computedCount: Int = 0
    public private(set) var skippedCount: Int = 0

    public init(
        fingerprinter: any AudioFingerprinting = AcoustIDFingerprintExtractor(),
        registry: LocalFingerprintRegistry = .shared
    ) {
        self.fingerprinter = fingerprinter
        self.registry = registry
    }

    /// Single track exact content signature retrieval.
    public func signature(for fileURL: URL) async throws -> ExactAudioSignature {
        let fp = try await fingerprint(for: fileURL)
        return ExactAudioSignature(value: fp.value, duration: fp.duration, algorithm: "sha256-pcm-v1")
    }

    /// Single track fingerprint retrieval with signature cache check and in-flight deduplication.
    /// Used by ImportPipeline to eliminate secondary schedulers.
    public func fingerprint(for fileURL: URL) async throws -> AudioFingerprint {
        let canonical = fileURL.resolvingSymlinksInPath().standardizedFileURL.path

        // 1. Check cache validity first
        if let cached = await registry.cachedFingerprint(for: fileURL),
           let record = await registry.lookup(fingerprint: cached, duration: 0, tolerance: 10000) {
            skippedCount += 1
            return AudioFingerprint(
                fingerprint: record.fingerprint,
                duration: record.duration,
                algorithm: "chromaprint-pcm-v1"
            )
        }

        // 2. In-flight task deduplication
        if let existing = inFlightTasks[canonical] {
            return try await existing.value
        }

        let task = Task<AudioFingerprint, Error> { [fingerprinter] in
            try await fingerprinter.generateFingerprint(for: fileURL)
        }
        inFlightTasks[canonical] = task

        do {
            let fp = try await task.value
            inFlightTasks.removeValue(forKey: canonical)
            computedCount += 1
            return fp
        } catch {
            inFlightTasks.removeValue(forKey: canonical)
            throw error
        }
    }

    /// Indexes a batch of tracks in the background.
    ///
    /// Pipeline:
    /// 1. Physical signature cache check (skips unchanged files completely).
    /// 2. Serial bounded decoding (prevents CoreMedia buffer spikes).
    /// 3. In-flight job deduplication.
    /// 4. Bounded batch commits to LocalFingerprintRegistry (minimal disk writes).
    @discardableResult
    public func indexTracks(
        _ tracks: [LocalTrack],
        chunkSize: Int = 50
    ) async -> FingerprintBatchResult {
        guard !tracks.isEmpty else {
            return FingerprintBatchResult(
                totalReceived: 0,
                skippedCachedCount: 0,
                newlyComputedCount: 0,
                persistenceWrites: await registry.persistenceWriteCount
            )
        }

        let initialWrites = await registry.persistenceWriteCount
        var batchSkipped = 0
        var batchComputed = 0
        var pendingItems: [FingerprintRegistrationItem] = []

        totalReceivedCount += tracks.count

        for track in tracks {
            let fileURL = track.fileURL
            guard LocalAudioFormatSupport.isNativeAppleFormat(fileURL) else {
                continue
            }

            // Check physical cache validity
            if await registry.hasValidRecord(for: fileURL) {
                batchSkipped += 1
                skippedCount += 1
                continue
            }

            // Calculate fingerprint using in-flight deduplication
            do {
                let fp = try await fingerprint(for: fileURL)
                batchComputed += 1

                pendingItems.append(FingerprintRegistrationItem(
                    fingerprint: fp.fingerprint,
                    duration: fp.duration,
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    artworkData: nil, // Do not bloat registry with raw artwork binary
                    fileURL: fileURL
                ))
            } catch {
                // Audio decode error for this specific track; continue to next
            }

            // Flush in bounded chunks to balance progress vs. atomic writes
            if pendingItems.count >= chunkSize {
                await registry.registerBatch(pendingItems)
                pendingItems.removeAll(keepingCapacity: true)
                await Task.yield()
            }
        }

        // Final flush of remaining items
        if !pendingItems.isEmpty {
            await registry.registerBatch(pendingItems)
            pendingItems.removeAll()
        }

        let currentWrites = await registry.persistenceWriteCount
        let batchWrites = currentWrites - initialWrites

        return FingerprintBatchResult(
            totalReceived: tracks.count,
            skippedCachedCount: batchSkipped,
            newlyComputedCount: batchComputed,
            persistenceWrites: batchWrites
        )
    }
}

/// Canonical typealias for ExactAudioSignatureService.
public typealias ExactAudioSignatureService = AudioFingerprintService

