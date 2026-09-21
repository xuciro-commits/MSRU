//
//  AudioFingerprintService.swift
//  MSRU
//
//  Created for Dedicated Background Acoustic Fingerprint Orchestration.
//

import Foundation
import AppFoundation

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

/// Dedicated background actor acting as the unique global owner of acoustic fingerprint
/// extraction, heuristic caching, in-flight task deduplication, and batched registry persistence.
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
