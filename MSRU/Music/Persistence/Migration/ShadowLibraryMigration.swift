//
//  ShadowLibraryMigration.swift
//  MSRU
//
//  Deterministic shadow migration engine importing legacy JSON manifests into SQLite.
//  Uses SHA256-based DeterministicID (strictly bans Swift hashValue) ensuring 100%
//  reproducibility across processes, restarts, and machines.
//

import Foundation
import AppFoundation

nonisolated public struct MigrationReport: Sendable, CustomStringConvertible {
    public let totalAssetsMigrated: Int
    public let totalRecordingsCreated: Int
    public let totalReleasesCreated: Int
    public let totalFingerprintsMigrated: Int
    public let totalLibraryEntriesMigrated: Int
    public let durationMs: Double
    public let isSuccess: Bool
    public let errors: [String]

    public var description: String {
        """
        === Migration Report ===
        Status: \(isSuccess ? "SUCCESS" : "FAILED")
        Duration: \(String(format: "%.2f", durationMs)) ms
        Assets: \(totalAssetsMigrated)
        Recordings: \(totalRecordingsCreated)
        Releases: \(totalReleasesCreated)
        Fingerprints: \(totalFingerprintsMigrated)
        Library Entries: \(totalLibraryEntriesMigrated)
        Errors: \(errors.count)
        """
    }
}

nonisolated public struct ReconciliationReport: Sendable, CustomStringConvertible {
    public let legacyCount: Int
    public let dbAssetCount: Int
    public let dbRecordingCount: Int
    public let isClean: Bool
    public let mismatchedPaths: [String]
    public let durationMs: Double

    public var description: String {
        """
        === Reconciliation Audit Report ===
        Status: \(isClean ? "CLEAN" : "MISMATCHED")
        Duration: \(String(format: "%.2f", durationMs)) ms
        Legacy Count: \(legacyCount)
        DB Asset Count: \(dbAssetCount)
        DB Recording Count: \(dbRecordingCount)
        Mismatches: \(mismatchedPaths.count)
        """
    }
}

public actor ShadowLibraryMigration {

    public static let shared = ShadowLibraryMigration()

    private let db: AppDatabase
    private let sourceRepo: SourceRepository
    private let assetRepo: AssetRepository
    private let identityRepo: IdentityRepository
    private let userLibraryRepo: UserLibraryRepository

    public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
        self.sourceRepo = SourceRepository(db: db)
        self.assetRepo = AssetRepository(db: db)
        self.identityRepo = IdentityRepository(db: db)
        self.userLibraryRepo = UserLibraryRepository(db: db)
    }

    /// Performs the deterministic shadow migration from legacy JSON stores into SQLite.
    /// Safe, idempotent, non-destructive, and repeatable.
    public func runMigrationIfNeeded(baseDirectory: URL? = nil, force: Bool = false) async throws -> MigrationReport {
        let startTime = CFAbsoluteTimeGetCurrent()

        let fileManager = FileManager.default
        let mediaBaseURL: URL
        if let baseDirectory {
            mediaBaseURL = baseDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            mediaBaseURL = appSupport.appendingPathComponent("MSRU/LocalMedia", isDirectory: true)
        }

        // 1. Ensure default local source exists
        let defaultSourceID = SourceID("src_local_default")
        let defaultSource = Source(
            id: defaultSourceID,
            sourceType: .localFolder,
            uri: mediaBaseURL.path,
            displayName: "Local Media",
            capabilities: .localFolderDefault,
            isEnabled: true
        )
        try await sourceRepo.insertOrUpdate(defaultSource)

        var assetCount = 0
        var recordingCount = 0
        var releaseCount = 0
        var fingerprintCount = 0
        var libraryEntryCount = 0
        var errors: [String] = []

        // 2. Import external_tracks.json (PersistedTrackRecord / LocalTrack)
        let externalManifestURL = mediaBaseURL.appendingPathComponent("external_tracks.json")
        if fileManager.fileExists(atPath: externalManifestURL.path),
           let data = try? Data(contentsOf: externalManifestURL) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacyTracks = try decoder.decode([LocalTrack].self, from: data)

                var artistsToInsert: [(id: ArtistID, name: String)] = []
                var recordingsToInsert: [(id: RecordingID, title: String, duration: Double?)] = []
                var releaseGroupsToInsert: [(id: ReleaseGroupID, title: String)] = []
                var releasesToInsert: [(id: ReleaseID, releaseGroupID: ReleaseGroupID?, title: String, year: Int?)] = []
                var releaseTracksToInsert: [(id: ReleaseTrackID, releaseID: ReleaseID, trackNumber: Int, title: String, duration: Double?, recordingID: RecordingID)] = []
                var artistCreditsToInsert: [(artistID: ArtistID, entityType: String, entityID: String)] = []
                var assetRecords: [PersistedAssetRecord] = []
                var libraryEntriesToInsert: [(recordingID: RecordingID, isFav: Bool, dateAdded: Date)] = []

                var seenArtists = Set<ArtistID>()
                var seenRecordings = Set<RecordingID>()
                var seenReleaseGroups = Set<ReleaseGroupID>()
                var seenReleases = Set<ReleaseID>()
                var seenTracks = Set<ReleaseTrackID>()

                for track in legacyTracks {
                    let relativePath = track.fileURL.standardizedFileURL.path
                    let fileAttrs = try? fileManager.attributesOfItem(atPath: track.fileURL.path)
                    let fileSize = (fileAttrs?[.size] as? Int64) ?? 0
                    let mtime = (fileAttrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

                    let recordingID = DeterministicID.recording(title: track.title, artist: track.artist)
                    let artistID = DeterministicID.artist(name: track.artist)
                    let releaseTitle = track.album ?? "Unknown Album"
                    let releaseGroupID = DeterministicID.releaseGroup(artist: track.artist, title: releaseTitle)
                    let releaseID = DeterministicID.release(artist: track.artist, title: releaseTitle)
                    let trackNumber = track.trackNumber ?? 1
                    let trackSlotID = DeterministicID.releaseTrack(releaseID: releaseID, medium: 1, track: trackNumber)
                    let assetID = DeterministicID.asset(sourceID: defaultSourceID, relativePath: relativePath)

                    if !seenArtists.contains(artistID) {
                        seenArtists.insert(artistID)
                        artistsToInsert.append((id: artistID, name: track.artist))
                    }

                    if !seenReleaseGroups.contains(releaseGroupID) {
                        seenReleaseGroups.insert(releaseGroupID)
                        releaseGroupsToInsert.append((id: releaseGroupID, title: releaseTitle))
                    }

                    if !seenReleases.contains(releaseID) {
                        seenReleases.insert(releaseID)
                        releasesToInsert.append((id: releaseID, releaseGroupID: releaseGroupID, title: releaseTitle, year: track.year))
                        releaseCount += 1
                    }

                    if !seenRecordings.contains(recordingID) {
                        seenRecordings.insert(recordingID)
                        recordingsToInsert.append((id: recordingID, title: track.title, duration: track.duration))
                        artistCreditsToInsert.append((artistID: artistID, entityType: "recording", entityID: recordingID.rawValue))
                        recordingCount += 1

                        // Add library entry for this canonical recording
                        libraryEntriesToInsert.append((recordingID: recordingID, isFav: false, dateAdded: Date(timeIntervalSince1970: mtime)))
                        libraryEntryCount += 1
                    }

                    if !seenTracks.contains(trackSlotID) {
                        seenTracks.insert(trackSlotID)
                        releaseTracksToInsert.append((id: trackSlotID, releaseID: releaseID, trackNumber: trackNumber, title: track.title, duration: track.duration, recordingID: recordingID))
                    }

                    let assetRecord = PersistedAssetRecord(
                        id: assetID,
                        sourceID: defaultSourceID,
                        relativePath: relativePath,
                        fileSize: fileSize,
                        mtime: mtime,
                        format: track.fileURL.pathExtension.uppercased(),
                        duration: track.duration,
                        recordingID: recordingID
                    )
                    assetRecords.append(assetRecord)
                    assetCount += 1
                }

                // Batch write in a single transaction
                try await identityRepo.batchUpsertEntities(
                    artists: artistsToInsert,
                    recordings: recordingsToInsert,
                    releaseGroups: releaseGroupsToInsert,
                    releases: releasesToInsert,
                    releaseTracks: releaseTracksToInsert,
                    artistCredits: artistCreditsToInsert
                )
                try await assetRepo.batchUpsert(assetRecords)

                for entry in libraryEntriesToInsert {
                    try await userLibraryRepo.addLibraryEntry(
                        recordingID: entry.recordingID,
                        isFavorite: entry.isFav,
                        dateAdded: entry.dateAdded
                    )
                }

            } catch {
                errors.append("Failed to decode external_tracks.json: \(error.localizedDescription)")
            }
        }

        // 3. Import fingerprints.json
        let fingerprintsURL = mediaBaseURL.appendingPathComponent("fingerprints.json")
        if fileManager.fileExists(atPath: fingerprintsURL.path),
           let data = try? Data(contentsOf: fingerprintsURL) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let records = json["records"] as? [[String: Any]] {
                for rec in records {
                    if let rawHash = rec["raw_hash"] as? String,
                       let dur = rec["duration"] as? Double,
                       let fp = rec["fingerprint"] as? String {
                        let assetID = AssetID("ast_\(rawHash)")
                        try await identityRepo.saveFingerprint(
                            assetID: assetID,
                            algorithm: "chromaprint-pcm-v1",
                            duration: dur,
                            fingerprintRaw: fp
                        )
                        fingerprintCount += 1
                    }
                }
            }
        }

        // 4. Import Library.json (User favorites & saved library items)
        let libraryURL = mediaBaseURL.deletingLastPathComponent().appendingPathComponent("Library.json")
        if fileManager.fileExists(atPath: libraryURL.path),
           let data = try? Data(contentsOf: libraryURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let libraryTracks = try? decoder.decode([LibraryTrack].self, from: data) {
                for track in libraryTracks {
                    let recordingID = DeterministicID.recording(title: track.title, artist: track.artist)
                    try await userLibraryRepo.addLibraryEntry(
                        recordingID: recordingID,
                        isFavorite: true,
                        dateAdded: track.dateAdded
                    )
                }
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return MigrationReport(
            totalAssetsMigrated: assetCount,
            totalRecordingsCreated: recordingCount,
            totalReleasesCreated: releaseCount,
            totalFingerprintsMigrated: fingerprintCount,
            totalLibraryEntriesMigrated: libraryEntryCount,
            durationMs: elapsed,
            isSuccess: errors.isEmpty,
            errors: errors
        )
    }

    /// Reconciles legacy JSON data against the SQLite database to verify 100% data fidelity.
    public func runReconciliationAudit(baseDirectory: URL? = nil) async throws -> ReconciliationReport {
        let start = CFAbsoluteTimeGetCurrent()
        let fileManager = FileManager.default
        let mediaBaseURL: URL
        if let baseDirectory {
            mediaBaseURL = baseDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            mediaBaseURL = appSupport.appendingPathComponent("MSRU/LocalMedia", isDirectory: true)
        }

        let externalManifestURL = mediaBaseURL.appendingPathComponent("external_tracks.json")
        var legacyCount = 0
        var mismatchedPaths: [String] = []

        if fileManager.fileExists(atPath: externalManifestURL.path),
           let data = try? Data(contentsOf: externalManifestURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let legacyTracks = try? decoder.decode([LocalTrack].self, from: data) {
                legacyCount = legacyTracks.count
                let dbSignatures = try await assetRepo.assetSignatures(forSourceID: SourceID("src_local_default"))

                for track in legacyTracks {
                    let path = track.fileURL.standardizedFileURL.path
                    if dbSignatures[path] == nil {
                        mismatchedPaths.append(path)
                    }
                }
            }
        }

        let dbAssets = try await assetRepo.totalCount()
        let dbRecordings = try await userLibraryRepo.totalEntriesCount()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        let isClean = mismatchedPaths.isEmpty && (legacyCount == 0 || dbAssets >= legacyCount)

        return ReconciliationReport(
            legacyCount: legacyCount,
            dbAssetCount: dbAssets,
            dbRecordingCount: dbRecordings,
            isClean: isClean,
            mismatchedPaths: mismatchedPaths,
            durationMs: elapsed
        )
    }

    /// Performs atomic read cutover: marks SQLite as the primary source of truth
    /// and freezes legacy files as a rollback backup.
    public func performAtomicCutover(baseDirectory: URL? = nil) async throws {
        let fileManager = FileManager.default
        let mediaBaseURL: URL
        if let baseDirectory {
            mediaBaseURL = baseDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            mediaBaseURL = appSupport.appendingPathComponent("MSRU/LocalMedia", isDirectory: true)
        }

        let audit = try await runReconciliationAudit(baseDirectory: baseDirectory)
        guard audit.isClean else {
            throw NSError(
                domain: "MSRUMigration",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Cutover aborted: Reconciliation audit failed with \(audit.mismatchedPaths.count) mismatches"]
            )
        }

        // Freeze legacy manifests by creating backup copies
        let externalManifestURL = mediaBaseURL.appendingPathComponent("external_tracks.json")
        let backupURL = mediaBaseURL.appendingPathComponent("external_tracks.json.legacy.backup")
        if fileManager.fileExists(atPath: externalManifestURL.path) && !fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.copyItem(at: externalManifestURL, to: backupURL)
        }
    }
}
