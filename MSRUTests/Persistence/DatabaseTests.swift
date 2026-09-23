//
//  DatabaseTests.swift
//  MSRUTests
//
//  Canonical persistence tests protecting database schema, foreign key cascades,
//  uniqueness constraints, transitive entity redirects, and FTS5 search indexing.
//

import Testing
import Foundation
import AppFoundation
import MusicDomain
import GRDB
import MusicLibrary
@testable import MSRU

@Suite("Database Persistence Invariants")
struct DatabaseTests {

    @Test
    func ephemeralDatabaseEnablesForeignKeysAndOpensSchema() throws {
        // Arrange & Act
        let appDb = try TestDatabase.makeEphemeral()

        // Assert
        let foreignKeysEnabled: Bool = try appDb.reader.read { db in
            let row = try Row.fetchOne(db, sql: "PRAGMA foreign_keys;")
            return (row?[0] as Int?) == 1
        }
        #expect(foreignKeysEnabled)
    }

    @Test
    func foreignKeyRejectionWhenSourceDoesNotExist() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let assetRepo = AssetRepository(db: appDb)
        let ghostSourceID = SourceID("src_ghost_nonexistent")
        let asset = PersistedAssetRecord(
            sourceID: ghostSourceID,
            relativePath: "album/track1.flac",
            fileSize: 1024,
            mtime: 1000.0,
            format: "FLAC"
        )

        // Act & Assert: Inserting an asset with an invalid foreign key must throw
        await #expect(throws: Error.self) {
            try await assetRepo.batchUpsert([asset])
        }
    }

    @Test
    func sourceDeletionCascadesToAssets() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb, id: SourceID("src_cascade_test"))
        let assetRepo = AssetRepository(db: appDb)

        let assetID = AssetID.generate()
        let asset = PersistedAssetRecord(
            id: assetID,
            sourceID: sourceID,
            relativePath: "test/track.mp3",
            fileSize: 5000,
            mtime: 12345.0,
            format: "MP3"
        )
        try await assetRepo.batchUpsert([asset])

        let countBefore: Int = try await appDb.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets WHERE source_id = ?", arguments: [sourceID.rawValue]) ?? 0
        }
        #expect(countBefore == 1)

        // Act: Delete source
        try await appDb.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM sources WHERE id = ?", arguments: [sourceID.rawValue])
        }

        // Assert: Cascaded to assets
        let countAfter: Int = try await appDb.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets WHERE source_id = ?", arguments: [sourceID.rawValue]) ?? 0
        }
        #expect(countAfter == 0)
    }

    @Test
    func recordingDeletionSetsAssetRecordingNullAndCascadesReleaseTrack() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb)
        let identityRepo = IdentityRepository(db: appDb)
        let assetRepo = AssetRepository(db: appDb)

        let recID = RecordingID.generate()
        let relID = ReleaseID.generate()
        let trkID = ReleaseTrackID.generate()
        let assetID = AssetID.generate()

        try await identityRepo.upsertRecording(id: recID, title: "Transient Recording")
        try await identityRepo.upsertRelease(id: relID, title: "Transient Release")
        try await identityRepo.upsertReleaseTrack(
            id: trkID,
            releaseID: relID,
            trackPosition: 1,
            trackNumber: "1",
            title: "Track 1",
            recordingID: recID
        )

        let asset = PersistedAssetRecord(
            id: assetID,
            sourceID: sourceID,
            relativePath: "music/track1.flac",
            fileSize: 1000,
            mtime: 100.0,
            format: "FLAC",
            recordingID: recID
        )
        try await assetRepo.batchUpsert([asset])

        // Act: Delete recording
        try await appDb.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recordings WHERE id = ?", arguments: [recID.rawValue])
        }

        // Assert 1: Asset still exists, but recording_id is set to NULL
        let assetRecordingID: String? = try await appDb.reader.read { db in
            try String.fetchOne(db, sql: "SELECT recording_id FROM assets WHERE id = ?", arguments: [assetID.rawValue])
        }
        #expect(assetRecordingID == nil)

        // Assert 2: ReleaseTrack was deleted via ON DELETE CASCADE
        let trackCount: Int = try await appDb.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM release_tracks WHERE id = ?", arguments: [trkID.rawValue]) ?? 0
        }
        #expect(trackCount == 0)
    }

    @Test
    func assetSourceAndPathUniquenessEnforced() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb)
        let assetRepo = AssetRepository(db: appDb)

        let sharedAssetID = AssetID.generate()
        let asset1 = PersistedAssetRecord(
            id: sharedAssetID,
            sourceID: sourceID,
            relativePath: "common/path.flac",
            fileSize: 1000,
            mtime: 1.0,
            format: "FLAC"
        )
        let asset2 = PersistedAssetRecord(
            id: sharedAssetID,
            sourceID: sourceID,
            relativePath: "common/path.flac",
            fileSize: 2000,
            mtime: 2.0,
            format: "FLAC"
        )

        // Act 1: batchUpsert updates existing row without creating duplicate
        try await assetRepo.batchUpsert([asset1])
        try await assetRepo.batchUpsert([asset2])

        // Assert 1: Only 1 asset row exists with updated metadata
        let updatedData: (fileSize: Int64, mtime: Double)? = try await appDb.reader.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT file_size, mtime FROM assets WHERE source_id = ? AND relative_path = ?",
                arguments: [sourceID.rawValue, "common/path.flac"]
            ) else { return nil }
            let fs: Int64 = row["file_size"]
            let mt: Double = row["mtime"]
            return (fs, mt)
        }
        #expect(updatedData != nil)
        #expect(updatedData?.fileSize == 2000)
        #expect(updatedData?.mtime == 2.0)

        // Act & Assert 2: Directly attempting to insert a second asset with the same path must throw
        await #expect(throws: Error.self) {
            try await appDb.dbWriter.write { db in
                try db.execute(sql: """
                    INSERT INTO assets (id, source_id, relative_path, file_size, mtime, format, sample_rate, duration, created_at, updated_at)
                    VALUES ('ast_duplicate_fail', ?, 'common/path.flac', 100, 1.0, 'FLAC', 44100, 10.0, '2026-01-01', '2026-01-01')
                """, arguments: [sourceID.rawValue])
            }
        }
    }

    @Test
    func entityRedirectsResolveTransitively() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let identityRepo = IdentityRepository(db: appDb)

        let initialID = "rec_provisional_1"
        let midID = "rec_provisional_2"
        let finalCanonicalID = "rec_canonical_final"

        // Act: Register chain: initialID -> midID -> finalCanonicalID
        try await identityRepo.recordEntityRedirect(
            sourceID: initialID,
            targetID: midID,
            entityType: "recording",
            reason: "deduplication"
        )
        try await identityRepo.recordEntityRedirect(
            sourceID: midID,
            targetID: finalCanonicalID,
            entityType: "recording",
            reason: "musicbrainz_match"
        )

        // Assert: initialID resolves directly to finalCanonicalID
        let resolved = try await identityRepo.resolvedEntityID(for: initialID, entityType: "recording")
        #expect(resolved == finalCanonicalID)
    }

    @Test
    func fts5InstantSearchFindsTokenizedTracks() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let identityRepo = IdentityRepository(db: appDb)

        let artistID = ArtistID("art_jay")
        let recID = RecordingID("rec_sunny")
        let relID = ReleaseID("rel_ye")
        let trkID = ReleaseTrackID("trk_sunny")

        try await identityRepo.batchUpsertEntities(
            artists: [(artistID, "周杰伦")],
            recordings: [(recID, "晴天", 269.0)],
            releaseGroups: [(ReleaseGroupID("rg_ye"), "叶惠美")],
            releases: [(relID, ReleaseGroupID("rg_ye"), "叶惠美", 2003)],
            releaseTracks: [(trkID, relID, 4, "晴天", 269.0, recID)],
            artistCredits: [(artistID, "recording", recID.rawValue)]
        )

        // Act: Search for song title and artist
        let foundTitle: String? = try await appDb.reader.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT track_title FROM library_fts WHERE library_fts MATCH ? LIMIT 1",
                arguments: ["晴天"]
            )
        }
        let foundArtist: String? = try await appDb.reader.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT recording_id FROM library_fts WHERE library_fts MATCH ? LIMIT 1",
                arguments: ["周杰伦"]
            )
        }

        // Assert
        #expect(foundTitle == "晴天")
        #expect(foundArtist == recID.rawValue)
    }
}
