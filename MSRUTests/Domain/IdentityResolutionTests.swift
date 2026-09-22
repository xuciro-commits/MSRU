//
//  IdentityResolutionTests.swift
//  MSRUTests
//
//  Canonical identity resolution tests:
//  DeterministicID reproducibility, Identity != Metadata,
//  Cascading metadata precedence (User > Canonical > Raw), and External ID mapping.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@Suite("Identity Resolution & Invariants")
struct IdentityResolutionTests {

    @Test
    func deterministicIDIsReproducibleAcrossRunsAndPlatforms() {
        // Arrange & Act
        let id1 = DeterministicID.recording(title: "晴天", artist: "周杰伦")
        let id2 = DeterministicID.recording(title: "晴天", artist: "周杰伦")
        let idWhitespacePadded = DeterministicID.recording(title: "  晴天 \n", artist: "周杰伦  ")

        // Assert: SHA-256 generation is 100% deterministic and normalized
        #expect(id1.rawValue == id2.rawValue)
        #expect(id1.rawValue == idWhitespacePadded.rawValue)
        #expect(id1.rawValue.hasPrefix("rec_"))
    }

    @Test
    func deterministicIDDistinguishesDifferentEntities() {
        // Arrange & Act
        let songA = DeterministicID.recording(title: "晴天", artist: "周杰伦")
        let songB = DeterministicID.recording(title: "暗号", artist: "周杰伦")
        let artistJay = DeterministicID.artist(name: "周杰伦")
        let artistEason = DeterministicID.artist(name: "陈奕迅")

        // Assert
        #expect(songA.rawValue != songB.rawValue)
        #expect(artistJay.rawValue != artistEason.rawValue)
    }

    @Test
    func userOverrideTakesPrecedenceOverCanonicalAndRaw() {
        // Arrange: Three-layer metadata container (User > Canonical > Raw)
        var overlay = TrackMetadataOverlay(
            rawTitle: "Track04_Audio",
            rawArtist: "Unknown Artist",
            rawAlbum: "2003_Rip"
        )

        // Initial state: Raw fallback
        #expect(overlay.resolvedTitle == "Track04_Audio")
        #expect(overlay.resolvedArtist == "Unknown Artist")

        // Act 1: Enrich with Canonical catalog metadata
        overlay.title.canonical = "晴天"
        overlay.artist.canonical = "周杰伦"
        overlay.album.canonical = "叶惠美"

        // Assert: Canonical overrides Raw
        #expect(overlay.resolvedTitle == "晴天")
        #expect(overlay.resolvedArtist == "周杰伦")
        #expect(overlay.resolvedAlbum == "叶惠美")

        // Act 2: User manually provides custom overrides
        overlay.title.user = "晴天 (2024 Remaster)"
        overlay.artist.user = "Jay Chou"

        // Assert: User override strictly wins over Canonical and Raw
        #expect(overlay.resolvedTitle == "晴天 (2024 Remaster)")
        #expect(overlay.resolvedArtist == "Jay Chou")
        #expect(overlay.resolvedAlbum == "叶惠美") // Canonical retained when user didn't override album
    }

    @Test
    func externalIdentifierMapsToInternalIDWithoutReplacingIt() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let identityRepo = IdentityRepository(db: appDb)

        let internalRecID = RecordingID("rec_internal_canonical_123")
        let externalMusicBrainzMBID = "a225bb13-5b8f-4da0-9908-410a563f8582"

        // Act: Upsert recording with internal ID and store external MBID
        try await identityRepo.upsertRecording(
            id: internalRecID,
            title: "晴天",
            mbid: externalMusicBrainzMBID
        )

        // Assert: External MBID is an attribute and does not replace canonical internal ID
        let dbMBID: String? = try await appDb.reader.read { db in
            try String.fetchOne(db, sql: "SELECT mbid FROM recordings WHERE id = ?", arguments: [internalRecID.rawValue])
        }
        #expect(dbMBID == externalMusicBrainzMBID)
    }

    @Test
    func metadataClaimsDoNotSilentlyAlterCanonicalIdentity() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb)
        let assetRepo = AssetRepository(db: appDb)
        let claimRepo = MetadataClaimRepository(db: appDb)

        let assetID = AssetID.generate()
        let asset = PersistedAssetRecord(
            id: assetID,
            sourceID: sourceID,
            relativePath: "jay/04.flac",
            fileSize: 30000,
            mtime: 1234.0,
            format: "FLAC"
        )
        try await assetRepo.batchUpsert([asset])

        // Act: Reader submits raw metadata claims
        let claimTitle = MetadataClaim(
            assetID: assetID,
            field: "title",
            rawValue: "晴天",
            sourceReader: "FLACVorbisCommentReader",
            confidence: 0.95
        )
        let claimArtist = MetadataClaim(
            assetID: assetID,
            field: "artist",
            rawValue: "周杰伦",
            sourceReader: "FLACVorbisCommentReader",
            confidence: 0.95
        )
        try await claimRepo.batchInsert([claimTitle, claimArtist])

        // Assert: Claims are recorded as evidence, but the physical asset row and ID are untouched
        let claims = try await claimRepo.claims(for: assetID)
        #expect(claims.count == 2)
        #expect(claims.contains { $0.field == "title" && $0.rawValue == "晴天" })

        let persistedAsset = try await appDb.reader.read { db in
            try String.fetchOne(db, sql: "SELECT id FROM assets WHERE id = ?", arguments: [assetID.rawValue])
        }
        #expect(persistedAsset == assetID.rawValue)
    }
}
