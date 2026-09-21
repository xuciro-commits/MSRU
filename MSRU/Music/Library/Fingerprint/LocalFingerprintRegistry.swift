//
//  LocalFingerprintRegistry.swift
//  MSRU
//
//  Created for Local Acoustic Fingerprint Memory & Disambiguation.
//

import Foundation
import Observation

/// A locally learned acoustic fingerprint association (pure content identity).
nonisolated public struct AcousticFingerprintRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { fingerprint }
    public let fingerprint: String
    public let duration: TimeInterval
    public var title: String
    public var artist: String
    public var album: String?
    public var trackNumber: Int?
    public var releaseMBID: String?
    public var recordingMBID: String?
    public var artworkData: Data?
    public let dateLearned: Date
    public var matchCount: Int

    public init(
        fingerprint: String,
        duration: TimeInterval,
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkData: Data? = nil,
        dateLearned: Date = Date(),
        matchCount: Int = 0
    ) {
        self.fingerprint = fingerprint
        self.duration = duration
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.releaseMBID = releaseMBID
        self.recordingMBID = recordingMBID
        self.artworkData = artworkData
        self.dateLearned = dateLearned
        self.matchCount = matchCount
    }
}

/// A physical file asset cache entry mapping a canonical filesystem state to an acoustic fingerprint.
nonisolated public struct AssetFingerprintEntry: Codable, Sendable, Equatable {
    public let canonicalPath: String
    public let fileSize: Int64
    public let modificationTime: TimeInterval
    public let fingerprint: String
    public let dateCached: Date

    public init(
        canonicalPath: String,
        fileSize: Int64,
        modificationDate: Date,
        fingerprint: String,
        dateCached: Date = Date()
    ) {
        self.canonicalPath = canonicalPath
        self.fileSize = fileSize
        self.modificationTime = modificationDate.timeIntervalSince1970
        self.fingerprint = fingerprint
        self.dateCached = dateCached
    }
}

/// Registration payload for a batch fingerprint ingestion item.
nonisolated public struct FingerprintRegistrationItem: Sendable {
    public let fingerprint: String
    public let duration: TimeInterval
    public let title: String
    public let artist: String
    public let album: String?
    public let trackNumber: Int?
    public let releaseMBID: String?
    public let recordingMBID: String?
    public let artworkData: Data?
    public let fileURL: URL?

    public init(
        fingerprint: String,
        duration: TimeInterval,
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkData: Data? = nil,
        fileURL: URL? = nil
    ) {
        self.fingerprint = fingerprint
        self.duration = duration
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.releaseMBID = releaseMBID
        self.recordingMBID = recordingMBID
        self.artworkData = artworkData
        self.fileURL = fileURL
    }
}

private struct RegistryStorage: Codable {
    var records: [AcousticFingerprintRecord]
    var assetCache: [String: AssetFingerprintEntry]
}

/// Central registry managing lightweight local acoustic fingerprint memory and asset cache.
@MainActor
@Observable
public final class LocalFingerprintRegistry {
    public static let shared = LocalFingerprintRegistry()

    public private(set) var records: [AcousticFingerprintRecord] = []
    public private(set) var assetCache: [String: AssetFingerprintEntry] = [:]
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Fingerprints", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("local_fingerprints.json")
        }
        load()
    }

    /// Fast lookup by exact fingerprint or duration proximity.
    public func lookup(fingerprint: String, duration: TimeInterval, tolerance: TimeInterval = 2.0) -> AcousticFingerprintRecord? {
        // 1. Exact fingerprint match
        if let exact = records.first(where: { $0.fingerprint == fingerprint }) {
            return exact
        }

        // 2. Duration proximity match if duration matches closely
        for record in records {
            if abs(record.duration - duration) <= tolerance && record.fingerprint == fingerprint {
                return record
            }
        }

        return nil
    }

    /// Checks if the physical file has a valid, unchanged fingerprint in the asset cache.
    /// Validates canonical path, file size, AND modification date.
    public func cachedFingerprint(for fileURL: URL) -> String? {
        let canonicalPath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: canonicalPath),
              let size = attrs[.size] as? Int64,
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }
        if let entry = assetCache[canonicalPath],
           entry.fileSize == size,
           abs(entry.modificationTime - modDate.timeIntervalSince1970) < 1.0 {
            if records.contains(where: { $0.fingerprint == entry.fingerprint }) {
                return entry.fingerprint
            }
        }
        return nil
    }

    /// Fast boolean check if the given audio file already has a valid asset record.
    public func hasValidRecord(for fileURL: URL) -> Bool {
        cachedFingerprint(for: fileURL) != nil
    }

    /// Records an authentic match event (e.g. during recognition/disambiguation).
    public func recordMatch(fingerprint: String) {
        if let idx = records.firstIndex(where: { $0.fingerprint == fingerprint }) {
            records[idx].matchCount += 1
            save()
        }
    }

    /// Registers or updates a batch of local fingerprint memory records and asset cache entries.
    /// Persists to disk at most once for the whole batch.
    public func registerBatch(_ items: [FingerprintRegistrationItem]) {
        guard !items.isEmpty else { return }
        var changed = false

        for item in items {
            if updateInMemory(item) {
                changed = true
            }
        }

        if changed {
            save()
        }
    }

    /// Registers or updates a single local fingerprint memory record and optional asset cache entry.
    /// Does NOT mutate matchCount; saves to disk only if content actually changed.
    public func register(
        fingerprint: String,
        duration: TimeInterval,
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkData: Data? = nil,
        fileURL: URL? = nil
    ) {
        let item = FingerprintRegistrationItem(
            fingerprint: fingerprint,
            duration: duration,
            title: title,
            artist: artist,
            album: album,
            trackNumber: trackNumber,
            releaseMBID: releaseMBID,
            recordingMBID: recordingMBID,
            artworkData: artworkData,
            fileURL: fileURL
        )
        registerBatch([item])
    }

    private func updateInMemory(_ item: FingerprintRegistrationItem) -> Bool {
        var changed = false

        if let idx = records.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            if records[idx].title != item.title {
                records[idx].title = item.title
                changed = true
            }
            if records[idx].artist != item.artist {
                records[idx].artist = item.artist
                changed = true
            }
            if let album = item.album, records[idx].album != album {
                records[idx].album = album
                changed = true
            }
            if let trackNumber = item.trackNumber, records[idx].trackNumber != trackNumber {
                records[idx].trackNumber = trackNumber
                changed = true
            }
            if let releaseMBID = item.releaseMBID, records[idx].releaseMBID != releaseMBID {
                records[idx].releaseMBID = releaseMBID
                changed = true
            }
            if let recordingMBID = item.recordingMBID, records[idx].recordingMBID != recordingMBID {
                records[idx].recordingMBID = recordingMBID
                changed = true
            }
            if let artworkData = item.artworkData, records[idx].artworkData != artworkData {
                records[idx].artworkData = artworkData
                changed = true
            }
        } else {
            let record = AcousticFingerprintRecord(
                fingerprint: item.fingerprint,
                duration: item.duration,
                title: item.title,
                artist: item.artist,
                album: item.album,
                trackNumber: item.trackNumber,
                releaseMBID: item.releaseMBID,
                recordingMBID: item.recordingMBID,
                artworkData: item.artworkData,
                matchCount: 0
            )
            records.append(record)
            changed = true
        }

        // Update asset cache if fileURL provided
        if let fileURL = item.fileURL {
            let canonicalPath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: canonicalPath),
               let size = attrs[.size] as? Int64,
               let modDate = attrs[.modificationDate] as? Date {
                let entry = AssetFingerprintEntry(
                    canonicalPath: canonicalPath,
                    fileSize: size,
                    modificationDate: modDate,
                    fingerprint: item.fingerprint
                )
                if assetCache[canonicalPath] != entry {
                    assetCache[canonicalPath] = entry
                    changed = true
                }
            }
        }

        return changed
    }

    /// Removes a record by fingerprint and cleans up associated asset cache entries.
    public func remove(fingerprint: String) {
        records.removeAll { $0.fingerprint == fingerprint }
        assetCache = assetCache.filter { $0.value.fingerprint != fingerprint }
        save()
    }

    /// Clears all local fingerprint memory and asset cache.
    public func removeAll() {
        records.removeAll()
        assetCache.removeAll()
        save()
    }

    /// Cleans up acoustic fingerprint records that are no longer referenced by any active tracks.
    @discardableResult
    public func cleanOrphanRecords(activeTracks: [LocalTrack]) -> Int {
        let activeKeys = Set(activeTracks.map {
            "\($0.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        })
        let activePaths = Set(activeTracks.map { $0.fileURL.resolvingSymlinksInPath().standardizedFileURL.path })

        let beforeCount = records.count
        records.removeAll { record in
            let key = "\(record.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\(record.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            return !activeKeys.contains(key)
        }
        assetCache = assetCache.filter { activePaths.contains($0.key) }

        let removed = beforeCount - records.count
        if removed > 0 {
            save()
        }
        return removed
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL) else {
            return
        }
        if let decoded = try? JSONDecoder().decode(RegistryStorage.self, from: data) {
            self.records = decoded.records
            self.assetCache = decoded.assetCache
        } else if let legacyRecords = try? JSONDecoder().decode([AcousticFingerprintRecord].self, from: data) {
            self.records = legacyRecords
            self.assetCache = [:]
        }
    }

    private func save() {
        let storage = RegistryStorage(records: records, assetCache: assetCache)
        guard let encoded = try? JSONEncoder().encode(storage) else { return }
        try? encoded.write(to: storageURL, options: .atomic)
    }
}
