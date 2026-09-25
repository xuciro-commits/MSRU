//
//  LibraryCleanupModel.swift
//  MSRU
//
//  Application-scoped library cleanup: at most one health scan or batch fix at
//  a time, shared by every window. Scanning and fixing run in the library's
//  background actors; this model only holds progress and results. A fix is
//  measured by rescanning, so the result shows what actually changed.
//

import Foundation
import Observation
import MusicLibrary

@MainActor
@Observable
final class LibraryCleanupModel {
    enum Fix: Equatable, Sendable {
        /// Look up titles, artists and albums in the catalogue ("Get Info").
        case info
        /// Find cover art in the folder, the file or the catalogue.
        case artwork
    }

    enum Phase: Equatable {
        case idle
        case scanning(LibraryHealthProgress)
        case fixing(Fix, done: Int, total: Int)
    }

    /// Outcome of the last fix, measured by the rescan that follows it.
    struct FixResult: Equatable {
        let fix: Fix
        let checked: Int
        let before: Int
        let after: Int
        var resolved: Int { max(0, before - after) }
    }

    /// Tracks per catalogue lookup; they are grouped by folder for album alignment.
    static let fixBatchSize = 20

    private(set) var report: LibraryHealthReport?
    private(set) var phase: Phase = .idle
    private(set) var lastFix: FixResult?
    private(set) var errorMessage: String?

    private let library: LocalLibraryStore
    private var task: Task<Void, Never>?

    init(library: LocalLibraryStore, report: LibraryHealthReport? = nil) {
        self.library = library
        self.report = report
    }

    var isBusy: Bool { phase != .idle }

    // MARK: - Actions

    func scan() {
        guard !isBusy else { return }
        task = Task { await runScan() }
    }

    /// Scans once if there is no report yet.
    func scanIfNeeded() {
        guard report == nil else { return }
        scan()
    }

    func fix(_ fix: Fix) {
        guard !isBusy, let report else { return }
        let paths = Self.paths(for: fix, in: report)
        guard !paths.isEmpty else { return }
        task = Task { await runFix(fix, paths: paths, before: paths.count) }
    }

    /// Stops the running scan or fix after the current batch. Finished batches stay applied.
    func cancel() {
        task?.cancel()
    }

    func stop() {
        cancel()
        task = nil
    }

    // MARK: - Work

    private func runScan() async {
        phase = .scanning(LibraryHealthProgress(scanned: 0, total: 0))
        defer { phase = .idle }
        do {
            report = try await library.scanHealth { progress in
                Task { @MainActor [weak self] in
                    guard let self, case .scanning = self.phase else { return }
                    self.phase = .scanning(progress)
                }
            }
            errorMessage = nil
        } catch is CancellationError {
            // Keep the previous report.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runFix(_ fix: Fix, paths: [String], before: Int) async {
        var checked = 0
        phase = .fixing(fix, done: 0, total: paths.count)
        for start in stride(from: 0, to: paths.count, by: Self.fixBatchSize) {
            if Task.isCancelled { break }
            let batch = Set(paths[start..<min(start + Self.fixBatchSize, paths.count)])
            do {
                let tracks = try await library.tracks(withIDs: batch)
                try await library.refreshMetadata(for: tracks)
            } catch is CancellationError {
                break
            } catch {
                errorMessage = error.localizedDescription
            }
            checked += batch.count
            phase = .fixing(fix, done: checked, total: paths.count)
        }

        phase = .idle
        await runScan()
        let after = report.map { Self.paths(for: fix, in: $0).count } ?? before
        lastFix = FixResult(fix: fix, checked: checked, before: before, after: after)
    }

    private static func paths(for fix: Fix, in report: LibraryHealthReport) -> [String] {
        switch fix {
        case .info: report.incompleteInfoPaths
        case .artwork: report.missingArtworkPaths
        }
    }
}
