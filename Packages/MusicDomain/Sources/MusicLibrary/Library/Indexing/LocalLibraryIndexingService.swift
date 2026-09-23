//
//  LocalLibraryIndexingService.swift
//  MSRU
//
//  Created for Decoupled Background Library Indexing Orchestration.
//

import Foundation
import MusicDomain

/// Lifecycle stages for local library background processing.
nonisolated public enum LibraryIndexingStage: Sendable, Equatable {
    case idle
    case indexing(inProgressCount: Int)
    case complete(totalProcessed: Int, skippedCount: Int)
}

/// Central coordinator actor managing the background indexing lifecycle (Acoustic Fingerprinting & Path Heuristics)
/// without coupling either subsystem to each other or to the UI MainActor.
public actor LocalLibraryIndexingService: Sendable {

    public static let shared = LocalLibraryIndexingService()

    private let fingerprintService: AudioFingerprintService
    private let learnRules: Bool
    private var pendingQueue: [URL: LocalTrack] = [:]
    private var activeTask: Task<Void, Never>?

    public private(set) var currentStage: LibraryIndexingStage = .idle

    public init(
        fingerprintService: AudioFingerprintService = .shared,
        learnRules: Bool = true
    ) {
        self.fingerprintService = fingerprintService
        self.learnRules = learnRules
    }

    /// Enqueues a batch of newly committed tracks for background indexing.
    /// Deduplicates in-flight jobs and merges incoming batches into the processing loop.
    public func enqueue(_ tracks: [LocalTrack]) {
        guard !tracks.isEmpty else { return }

        for track in tracks {
            pendingQueue[track.fileURL] = track
        }

        if activeTask == nil {
            activeTask = Task { [weak self] in
                await self?.processQueue()
            }
        }
    }

    /// Cancels any active background indexing loop and purges the pending queue.
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        pendingQueue.removeAll()
        currentStage = .idle
    }

    private func processQueue() async {
        var totalProcessed = 0
        var totalSkipped = 0

        while !pendingQueue.isEmpty && !Task.isCancelled {
            // Snapshot current queue items and clear pending buffer
            let currentBatch = Array(pendingQueue.values)
            pendingQueue.removeAll(keepingCapacity: true)

            currentStage = .indexing(inProgressCount: currentBatch.count)

            // Stage 2A: Delegate to AudioFingerprintService (background serial decode + physical signature check)
            let fpResult = await fingerprintService.indexTracks(currentBatch)
            totalProcessed += fpResult.totalReceived
            totalSkipped += fpResult.skippedCachedCount

            // Stage 2B: Delegate to PathHeuristicRuleStore (batched rule learning)
            if learnRules {
                await MainActor.run {
                    PathHeuristicRuleStore.shared.learnBatch(from: currentBatch)
                }
            }

            await Task.yield()
        }

        activeTask = nil
        currentStage = .complete(totalProcessed: totalProcessed, skippedCount: totalSkipped)
    }
}
