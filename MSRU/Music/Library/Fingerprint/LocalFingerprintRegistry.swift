//
//  LocalFingerprintRegistry.swift
//  MSRU
//
//  Created for Local Acoustic Fingerprint Memory & Disambiguation.
//

import Foundation
import AppFoundation
import GRDB

/// A locally learned exact-content audio signature association (Exactness Evidence).
nonisolated public struct AcousticFingerprintRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { fingerprint }
    public let fingerprint: String
    public let duration: TimeInterval
    public var algorithm: String
    public var title: String
    public var artist: String
    public var album: String?
    public var trackNumber: Int?
    public var releaseMBID: String?
    public var recordingMBID: String?
    public var artworkReference: String?
    public let dateLearned: Date
    public var matchCount: Int

    public var artworkData: Data? {
        artworkReference.flatMap { LocalArtworkStorage.shared.loadArtwork(relativePath: $0) }
    }

    public init(
        fingerprint: String,
        duration: TimeInterval,
        algorithm: String = "sha256-pcm-v1",
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkReference: String? = nil,
        artworkData: Data? = nil,
        dateLearned: Date = Date(),
        matchCount: Int = 0
    ) {
        self.fingerprint = fingerprint
        self.duration = duration
        self.algorithm = algorithm
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.releaseMBID = releaseMBID
        self.recordingMBID = recordingMBID
        if let artworkReference, !artworkReference.isEmpty {
            self.artworkReference = artworkReference
        } else if let artworkData, !artworkData.isEmpty {
            self.artworkReference = LocalArtworkStorage.shared.storeArtwork(artworkData)
        } else {
            self.artworkReference = nil
        }
        self.dateLearned = dateLearned
        self.matchCount = matchCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fingerprint = try container.decode(String.self, forKey: .fingerprint)
        self.duration = try container.decode(TimeInterval.self, forKey: .duration)
        self.algorithm = try container.decodeIfPresent(String.self, forKey: .algorithm) ?? "sha256-pcm-v1"
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.album = try container.decodeIfPresent(String.self, forKey: .album)
        self.trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
        self.releaseMBID = try container.decodeIfPresent(String.self, forKey: .releaseMBID)
        self.recordingMBID = try container.decodeIfPresent(String.self, forKey: .recordingMBID)
        self.artworkReference = try container.decodeIfPresent(String.self, forKey: .artworkReference)
        self.dateLearned = try container.decodeIfPresent(Date.self, forKey: .dateLearned) ?? Date()
        self.matchCount = try container.decodeIfPresent(Int.self, forKey: .matchCount) ?? 0
    }
}

/// Canonical typealias for ExactAudioSignatureRecord.
public typealias ExactAudioSignatureRecord = AcousticFingerprintRecord



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

nonisolated public struct FingerprintRegistrationItem: Sendable {
    public let fingerprint: String
    public let duration: TimeInterval
    public let title: String
    public let artist: String
    public let album: String?
    public let trackNumber: Int?
    public let releaseMBID: String?
    public let recordingMBID: String?
    public let artworkReference: String?
    public let fileURL: URL?

    public var artworkData: Data? {
        artworkReference.flatMap { LocalArtworkStorage.shared.loadArtwork(relativePath: $0) }
    }

    public init(
        fingerprint: String,
        duration: TimeInterval,
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkReference: String? = nil,
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
        if let artworkReference, !artworkReference.isEmpty {
            self.artworkReference = artworkReference
        } else if let artworkData, !artworkData.isEmpty {
            self.artworkReference = LocalArtworkStorage.shared.storeArtwork(artworkData)
        } else {
            self.artworkReference = nil
        }
        self.fileURL = fileURL
    }
}

nonisolated private struct RegistryStorage: Codable {
    var records: [AcousticFingerprintRecord]
    var assetCache: [String: AssetFingerprintEntry]
    var signatures: [String: AudioFileSignature]?
}

/// Dedicated background storage actor managing local exact audio signature memory,
/// file cache signatures, and atomic batch persistence off the main thread.
public actor LocalFingerprintRegistry: Sendable {
    public static let shared = LocalFingerprintRegistry()

    public private(set) var records: [AcousticFingerprintRecord]
    public private(set) var assetCache: [String: AssetFingerprintEntry]
    public private(set) var signatures: [String: AudioFileSignature]
    public private(set) var persistenceWriteCount: Int = 0

    private let db: AppDatabase
    private let storageURL: URL

    public init(db: AppDatabase = AppDatabase.shared, storageURL: URL? = nil) {
        self.db = db
        let finalURL: URL
        if let storageURL {
            finalURL = storageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Fingerprints", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            finalURL = dir.appendingPathComponent("local_fingerprints.json")
        }
        self.storageURL = finalURL

        let loaded = Self.load(db: db, from: finalURL)
        self.records = loaded.records
        self.assetCache = loaded.assetCache
        self.signatures = loaded.signatures
    }

    private func sanitizeRecord(_ record: AcousticFingerprintRecord) -> AcousticFingerprintRecord {
        if let alb = record.album, FileNameHeuristicParser.isGenericFolderName(alb) {
            return AcousticFingerprintRecord(
                fingerprint: record.fingerprint,
                duration: record.duration,
                algorithm: record.algorithm,
                title: record.title,
                artist: record.artist,
                album: nil,
                trackNumber: record.trackNumber,
                releaseMBID: record.releaseMBID,
                recordingMBID: record.recordingMBID,
                artworkReference: record.artworkReference,
                dateLearned: record.dateLearned,
                matchCount: record.matchCount
            )
        }
        return record
    }

    /// Fast lookup by exact fingerprint or duration proximity.
    public func lookup(fingerprint: String, duration: TimeInterval, tolerance: TimeInterval = 2.0) -> AcousticFingerprintRecord? {
        // 1. Exact fingerprint match
        if let exact = records.first(where: { $0.fingerprint == fingerprint }) {
            return sanitizeRecord(exact)
        }

        // 2. Duration proximity match if duration matches closely
        for record in records {
            if abs(record.duration - duration) <= tolerance && record.fingerprint == fingerprint {
                return sanitizeRecord(record)
            }
        }

        return nil
    }

    /// Validates whether the given audio file has a valid cache entry using physical file signatures.
    public func hasValidRecord(for fileURL: URL) -> Bool {
        cachedFingerprint(for: fileURL) != nil
    }

    /// Checks if the physical file has a valid, unchanged fingerprint signature in cache.
    public func cachedFingerprint(for fileURL: URL) -> String? {
        let canonicalPath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path

        // Check modern AudioFileSignature first
        if let sig = signatures[canonicalPath], sig.matches(fileURL: fileURL) {
            if let entry = assetCache[canonicalPath], records.contains(where: { $0.fingerprint == entry.fingerprint }) {
                return entry.fingerprint
            }
        }

        // Fallback for legacy asset cache entries
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

    /// Registers or updates a single local fingerprint memory record.
    /// Saves to disk only if content actually changed.
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

        let cleanAlbum = (item.album.map(FileNameHeuristicParser.isGenericFolderName) == true) ? nil : item.album

        if let idx = records.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            if records[idx].title != item.title {
                records[idx].title = item.title
                changed = true
            }
            if records[idx].artist != item.artist {
                records[idx].artist = item.artist
                changed = true
            }
            if let cleanAlbum, records[idx].album != cleanAlbum {
                records[idx].album = cleanAlbum
                changed = true
            } else if records[idx].album.map(FileNameHeuristicParser.isGenericFolderName) == true {
                records[idx].album = cleanAlbum
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
            if let artworkReference = item.artworkReference, records[idx].artworkReference != artworkReference {
                records[idx].artworkReference = artworkReference
                changed = true
            }
        } else {
            let record = AcousticFingerprintRecord(
                fingerprint: item.fingerprint,
                duration: item.duration,
                title: item.title,
                artist: item.artist,
                album: cleanAlbum,
                trackNumber: item.trackNumber,
                releaseMBID: item.releaseMBID,
                recordingMBID: item.recordingMBID,
                artworkReference: item.artworkReference,
                matchCount: 0
            )
            records.append(record)
            changed = true
        }

        // Update asset cache & physical signatures if fileURL provided
        if let fileURL = item.fileURL {
            let canonicalPath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            if let sig = AudioFileSignature(fileURL: fileURL) {
                if signatures[canonicalPath] != sig {
                    signatures[canonicalPath] = sig
                    changed = true
                }
                let entry = AssetFingerprintEntry(
                    canonicalPath: canonicalPath,
                    fileSize: sig.fileSize,
                    modificationDate: Date(timeIntervalSince1970: sig.modificationTime),
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
        signatures = signatures.filter { assetCache[$0.key] != nil }
        save()
    }

    /// Clears all local fingerprint memory and asset cache.
    public func removeAll() {
        records.removeAll()
        assetCache.removeAll()
        signatures.removeAll()
        save()
    }

    /// Cleans up acoustic fingerprint records that are no longer referenced by any active tracks.
    @discardableResult
    public func cleanOrphanRecords(activeTracks: [LocalTrack]) -> Int {
        let activeKeys = Set(activeTracks.map {
            "\($0.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        })
        let activePaths = Set(activeTracks.map { $0.fileURL.resolvingSymlinksInPath().standardizedFileURL.path })
        return cleanOrphanRecords(activeKeys: activeKeys, activePaths: activePaths)
    }

    @discardableResult
    public func cleanOrphanRecords(activeKeys: Set<String>, activePaths: Set<String>) -> Int {
        let beforeCount = records.count
        let beforeCacheCount = assetCache.count
        let beforeSignatureCount = signatures.count
        records.removeAll { record in
            let key = "\(record.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\(record.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            return !activeKeys.contains(key)
        }
        assetCache = assetCache.filter { activePaths.contains($0.key) }
        signatures = signatures.filter { activePaths.contains($0.key) }

        let removed = beforeCount - records.count
        if removed > 0 || assetCache.count != beforeCacheCount || signatures.count != beforeSignatureCount {
            save()
        }
        return removed
    }

    nonisolated private static func load(db: AppDatabase, from storageURL: URL) -> (records: [AcousticFingerprintRecord], assetCache: [String: AssetFingerprintEntry], signatures: [String: AudioFileSignature]) {
        // 1. One-time migration of legacy JSON file if present
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL) {
            var legacyRecords: [AcousticFingerprintRecord] = []
            var legacyCache: [String: AssetFingerprintEntry] = [:]
            var legacySignatures: [String: AudioFileSignature] = [:]

            if let decoded = try? JSONDecoder().decode(RegistryStorage.self, from: data) {
                legacyRecords = decoded.records
                legacyCache = decoded.assetCache
                legacySignatures = decoded.signatures ?? [:]
            } else if let recs = try? JSONDecoder().decode([AcousticFingerprintRecord].self, from: data) {
                legacyRecords = recs
            }

            if !legacyRecords.isEmpty || !legacyCache.isEmpty || !legacySignatures.isEmpty {
                try? db.dbWriter.write { db in
                    for r in legacyRecords {
                        try db.execute(
                            sql: """
                            INSERT OR REPLACE INTO fingerprint_records (fingerprint, duration, algorithm, title, artist, album, track_number, release_mbid, recording_mbid, artwork_reference, date_learned, match_count)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                            arguments: [r.fingerprint, r.duration, r.algorithm, r.title, r.artist, r.album, r.trackNumber, r.releaseMBID, r.recordingMBID, r.artworkReference, r.dateLearned, r.matchCount]
                        )
                    }
                    for (p, c) in legacyCache {
                        try db.execute(
                            sql: """
                            INSERT OR REPLACE INTO asset_fingerprint_cache (file_path, fingerprint, duration, mtime, file_size)
                            VALUES (?, ?, ?, ?, ?)
                            """,
                            arguments: [p, c.fingerprint, 0.0, c.modificationTime, c.fileSize]
                        )
                    }
                    for (p, s) in legacySignatures {
                        try db.execute(
                            sql: """
                            INSERT OR REPLACE INTO audio_file_signatures (file_path, file_size, mtime, inode, sha256)
                            VALUES (?, ?, ?, ?, ?)
                            """,
                            arguments: [s.canonicalPath, s.fileSize, s.modificationTime, nil, ""]
                        )
                    }
                }
            }
            try? FileManager.default.removeItem(at: storageURL)
        }

        // 2. Load from SQLite tables
        let loaded = try? db.reader.read { db -> (records: [AcousticFingerprintRecord], assetCache: [String: AssetFingerprintEntry], signatures: [String: AudioFileSignature]) in
            let recRows = try Row.fetchAll(db, sql: "SELECT * FROM fingerprint_records")
            let records = recRows.compactMap { row -> AcousticFingerprintRecord? in
                guard let fp: String = row["fingerprint"],
                      let dur: Double = row["duration"],
                      let algo: String = row["algorithm"],
                      let title: String = row["title"],
                      let artist: String = row["artist"],
                      let dateLearned: Date = row["date_learned"] else { return nil }
                let alb: String? = row["album"]
                let trkNum: Int? = row["track_number"]
                let relMBID: String? = row["release_mbid"]
                let recMBID: String? = row["recording_mbid"]
                let artRef: String? = row["artwork_reference"]
                let matchCount: Int = row["match_count"] ?? 1

                return AcousticFingerprintRecord(
                    fingerprint: fp,
                    duration: dur,
                    algorithm: algo,
                    title: title,
                    artist: artist,
                    album: alb,
                    trackNumber: trkNum,
                    releaseMBID: relMBID,
                    recordingMBID: recMBID,
                    artworkReference: artRef,
                    dateLearned: dateLearned,
                    matchCount: matchCount
                )
            }

            let cacheRows = try Row.fetchAll(db, sql: "SELECT * FROM asset_fingerprint_cache")
            var assetCache: [String: AssetFingerprintEntry] = [:]
            for row in cacheRows {
                guard let path: String = row["file_path"],
                      let fp: String = row["fingerprint"],
                      let mtime: Double = row["mtime"],
                      let fsize: Int64 = row["file_size"] else { continue }
                assetCache[path] = AssetFingerprintEntry(
                    canonicalPath: path,
                    fileSize: fsize,
                    modificationDate: Date(timeIntervalSince1970: mtime),
                    fingerprint: fp
                )
            }

            let sigRows = try Row.fetchAll(db, sql: "SELECT * FROM audio_file_signatures")
            var signatures: [String: AudioFileSignature] = [:]
            for row in sigRows {
                guard let path: String = row["file_path"],
                      let fsize: Int64 = row["file_size"],
                      let mtime: Double = row["mtime"] else { continue }
                signatures[path] = AudioFileSignature(
                    canonicalPath: path,
                    fileSize: fsize,
                    modificationTime: mtime
                )
            }

            return (records, assetCache, signatures)
        }

        return loaded ?? ([], [:], [:])
    }

    private func save() {
        let currentRecords = records
        let currentCache = assetCache
        let currentSigs = signatures

        try? db.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM fingerprint_records")
            for r in currentRecords {
                try db.execute(
                    sql: """
                    INSERT INTO fingerprint_records (fingerprint, duration, algorithm, title, artist, album, track_number, release_mbid, recording_mbid, artwork_reference, date_learned, match_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [r.fingerprint, r.duration, r.algorithm, r.title, r.artist, r.album, r.trackNumber, r.releaseMBID, r.recordingMBID, r.artworkReference, r.dateLearned, r.matchCount]
                )
            }

            try db.execute(sql: "DELETE FROM asset_fingerprint_cache")
            for (p, c) in currentCache {
                try db.execute(
                    sql: """
                    INSERT INTO asset_fingerprint_cache (file_path, fingerprint, duration, mtime, file_size)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [p, c.fingerprint, 0.0, c.modificationTime, c.fileSize]
                )
            }

            try db.execute(sql: "DELETE FROM audio_file_signatures")
            for (p, s) in currentSigs {
                try db.execute(
                    sql: """
                    INSERT INTO audio_file_signatures (file_path, file_size, mtime, inode, sha256)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [s.canonicalPath, s.fileSize, s.modificationTime, nil, ""]
                )
            }
        }
        persistenceWriteCount += 1
    }
}

/// Canonical typealias for LocalAudioSignatureRegistry.
public typealias LocalAudioSignatureRegistry = LocalFingerprintRegistry
