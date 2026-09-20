//
//  SafeFileOrganizer.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation

/// Defines the operation to perform on a file.
public enum FileMoveOperationKind: String, Sendable, Codable {
    case move
    case copy
}

/// A planned single-file relocation or copy operation.
public struct FileMoveItem: Sendable, Equatable, Hashable, Codable, Identifiable {
    public var id: String { sourceURL.absoluteString }
    public let sourceURL: URL
    public let targetURL: URL
    public let kind: FileMoveOperationKind
    public let isConflict: Bool
    public let fileSize: Int64

    public init(
        sourceURL: URL,
        targetURL: URL,
        kind: FileMoveOperationKind = .move,
        isConflict: Bool = false,
        fileSize: Int64 = 0
    ) {
        self.sourceURL = sourceURL
        self.targetURL = targetURL
        self.kind = kind
        self.isConflict = isConflict
        self.fileSize = fileSize
    }
}

/// A pre-computed file relocation plan ready for user review or dry-run execution.
public struct FileOrganizationPlan: Sendable, Equatable, Codable {
    public let items: [FileMoveItem]
    public let totalBytes: Int64
    public let hasConflicts: Bool

    public init(items: [FileMoveItem] = []) {
        self.items = items
        self.totalBytes = items.reduce(0) { $0 + $1.fileSize }
        self.hasConflicts = items.contains(where: { $0.isConflict })
    }
}

/// Execution outcome including an audit undo log.
public struct FileOrganizationResult: Sendable, Equatable {
    public let executedItems: [FileMoveItem]
    public let failedItems: [(item: FileMoveItem, error: String)]
    public let isDryRun: Bool

    public var isCompleteSuccess: Bool {
        failedItems.isEmpty
    }

    public init(
        executedItems: [FileMoveItem] = [],
        failedItems: [(item: FileMoveItem, error: String)] = [],
        isDryRun: Bool = false
    ) {
        self.executedItems = executedItems
        self.failedItems = failedItems
        self.isDryRun = isDryRun
    }

    public static func == (lhs: FileOrganizationResult, rhs: FileOrganizationResult) -> Bool {
        lhs.executedItems == rhs.executedItems &&
        lhs.failedItems.count == rhs.failedItems.count &&
        lhs.isDryRun == rhs.isDryRun
    }
}

/// Safe file organization engine that prevents accidental overwrites and provides pre-flight dry-runs.
public enum SafeFileOrganizer {

    /// Generates a relocation plan, resolving naming collisions by appending numeric suffixes like ` (1)`.
    public static func generatePlan(
        candidatePairs: [(source: URL, desiredTarget: URL, size: Int64)],
        kind: FileMoveOperationKind = .move,
        targetExistsChecker: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> FileOrganizationPlan {
        var plannedItems: [FileMoveItem] = []
        var reservedPaths = Set<String>()

        for candidate in candidatePairs {
            let source = candidate.source
            let desired = candidate.desiredTarget

            // If source and desired target are literally identical on disk, skip or keep as is
            if source.standardizedFileURL.path == desired.standardizedFileURL.path {
                continue
            }

            var finalTarget = desired
            var hadConflict = false

            // If target already exists on disk OR was reserved by an earlier item in this same batch
            if targetExistsChecker(finalTarget) || reservedPaths.contains(finalTarget.path) {
                hadConflict = true
                finalTarget = resolveUniqueTarget(
                    desired: desired,
                    targetExistsChecker: targetExistsChecker,
                    reservedPaths: reservedPaths
                )
            }

            reservedPaths.insert(finalTarget.path)

            plannedItems.append(FileMoveItem(
                sourceURL: source,
                targetURL: finalTarget,
                kind: kind,
                isConflict: hadConflict,
                fileSize: candidate.size
            ))
        }

        return FileOrganizationPlan(items: plannedItems)
    }

    /// Executes the plan with safety checks and automatic parent directory creation.
    ///
    /// When `dryRun == true`, returns simulated execution without altering disk contents.
    public static func execute(
        plan: FileOrganizationPlan,
        dryRun: Bool = false,
        fileManager: FileManager = .default
    ) -> FileOrganizationResult {
        if dryRun {
            return FileOrganizationResult(
                executedItems: plan.items,
                failedItems: [],
                isDryRun: true
            )
        }

        var executed: [FileMoveItem] = []
        var failed: [(item: FileMoveItem, error: String)] = []

        for item in plan.items {
            do {
                let targetDir = item.targetURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: targetDir.path) {
                    try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                }

                switch item.kind {
                case .move:
                    try fileManager.moveItem(at: item.sourceURL, to: item.targetURL)
                case .copy:
                    try fileManager.copyItem(at: item.sourceURL, to: item.targetURL)
                }

                executed.append(item)
            } catch {
                failed.append((item: item, error: error.localizedDescription))
            }
        }

        return FileOrganizationResult(
            executedItems: executed,
            failedItems: failed,
            isDryRun: false
        )
    }

    /// Reverts previously moved items by relocating them back to their original source paths.
    public static func undo(
        executedItems: [FileMoveItem],
        fileManager: FileManager = .default
    ) throws {
        for item in executedItems.reversed() {
            guard fileManager.fileExists(atPath: item.targetURL.path) else { continue }
            switch item.kind {
            case .move:
                let originalDir = item.sourceURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: originalDir.path) {
                    try fileManager.createDirectory(at: originalDir, withIntermediateDirectories: true)
                }
                try fileManager.moveItem(at: item.targetURL, to: item.sourceURL)
            case .copy:
                try fileManager.removeItem(at: item.targetURL)
            }
        }
    }

    // MARK: - Collision Helpers

    private static func resolveUniqueTarget(
        desired: URL,
        targetExistsChecker: (URL) -> Bool,
        reservedPaths: Set<String>
    ) -> URL {
        let parentDir = desired.deletingLastPathComponent()
        let filename = desired.deletingPathExtension().lastPathComponent
        let ext = desired.pathExtension

        var counter = 1
        while counter < 1000 {
            let candidateName = "\(filename) (\(counter))"
            let candidateURL: URL
            if ext.isEmpty {
                candidateURL = parentDir.appendingPathComponent(candidateName)
            } else {
                candidateURL = parentDir.appendingPathComponent("\(candidateName).\(ext)")
            }

            if !targetExistsChecker(candidateURL) && !reservedPaths.contains(candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }

        // Fallback with UUID if 1000 collisions encountered
        let uuidSuffix = UUID().uuidString.prefix(8)
        let fallbackName = "\(filename)_\(uuidSuffix)"
        return ext.isEmpty
            ? parentDir.appendingPathComponent(fallbackName)
            : parentDir.appendingPathComponent("\(fallbackName).\(ext)")
    }
}
