//
//  WatchedFolderScanner.swift
//  MSRU
//
//  Created for Background Folder Reconciliation.
//

import Foundation

nonisolated public struct FolderReconciliationResult: Sendable {
    public let newTracks: [LocalTrack]
    public let modifiedTracks: [LocalTrack]
    public let deletedTrackPaths: [String]
    public let totalScannedCount: Int
    public let discoveredCount: Int

    public init(
        newTracks: [LocalTrack],
        modifiedTracks: [LocalTrack] = [],
        deletedTrackPaths: [String] = [],
        totalScannedCount: Int,
        discoveredCount: Int
    ) {
        self.newTracks = newTracks
        self.modifiedTracks = modifiedTracks
        self.deletedTrackPaths = deletedTrackPaths
        self.totalScannedCount = totalScannedCount
        self.discoveredCount = discoveredCount
    }
}

/// Dedicated actor performing filesystem directory traversal and audio metadata parsing off the main thread.
public actor WatchedFolderScanner {
    public init() {}

    /// Recursively collects all supported audio file URLs within a directory.
    public func collectAudioFiles(at directory: URL) -> [URL] {
        var results: [URL] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let pathExt = fileURL.pathExtension.lowercased()
            if LocalAudioFormatSupport.supports(extension: pathExt) {
                results.append(fileURL)
            }
        }
        return results
    }

    /// Reconciles disk files against known tracks in this folder.
    /// Runs off @MainActor. Unchanged tracks produce 0 metadata reads and 0 track emissions.
    public func reconcileFolder(
        targetURL: URL,
        existingTracksInFolder: [LocalTrack],
        assetCache: [String: AssetFingerprintEntry] = [:],
        signatures: [String: AudioFileSignature] = [:]
    ) async -> FolderReconciliationResult {
        let allAudioURLs = collectAudioFiles(at: targetURL)
        let existingMap = Dictionary(
            uniqueKeysWithValues: existingTracksInFolder.map { ($0.fileURL.standardizedFileURL.path, $0) }
        )

        var currentPaths = Set<String>()
        var newAudioURLs: [URL] = []
        var modifiedAudioURLs: [URL] = []

        for audioURL in allAudioURLs {
            let stdPath = audioURL.standardizedFileURL.path
            currentPaths.insert(stdPath)

            if existingMap[stdPath] == nil {
                newAudioURLs.append(audioURL)
            } else {
                let canonicalPath = audioURL.resolvingSymlinksInPath().standardizedFileURL.path
                if let sig = signatures[canonicalPath] {
                    if !sig.matches(fileURL: audioURL) {
                        modifiedAudioURLs.append(audioURL)
                    }
                } else if let cached = assetCache[canonicalPath] {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: canonicalPath),
                       let size = attrs[.size] as? Int64,
                       let modDate = attrs[.modificationDate] as? Date,
                       cached.fileSize == size,
                       abs(cached.modificationTime - modDate.timeIntervalSince1970) < 1.0 {
                        // Unmodified
                    } else {
                        modifiedAudioURLs.append(audioURL)
                    }
                }
            }
        }

        // Deleted tracks: present in library under this folder, but absent on disk
        var deletedPaths: [String] = []
        for (existingPath, _) in existingMap {
            if !currentPaths.contains(existingPath) {
                deletedPaths.append(existingPath)
            }
        }

        // Parse metadata off @MainActor
        var newTracks: [LocalTrack] = []
        for url in newAudioURLs {
            do {
                let track = try await FileLocalLibraryRepository.readTrack(from: url)
                newTracks.append(track)
            } catch {
                print("Scanner failed to read new track:", url.lastPathComponent, error.localizedDescription)
            }
            await Task.yield()
        }

        var modifiedTracks: [LocalTrack] = []
        for url in modifiedAudioURLs {
            do {
                let track = try await FileLocalLibraryRepository.readTrack(from: url)
                modifiedTracks.append(track)
            } catch {
                print("Scanner failed to read modified track:", url.lastPathComponent, error.localizedDescription)
            }
            await Task.yield()
        }

        return FolderReconciliationResult(
            newTracks: newTracks,
            modifiedTracks: modifiedTracks,
            deletedTrackPaths: deletedPaths,
            totalScannedCount: allAudioURLs.count,
            discoveredCount: newTracks.count + modifiedTracks.count
        )
    }
}
