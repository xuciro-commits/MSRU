//
//  LibraryTests.swift
//  MSRUTests
//
//  Canonical library tests protecting user library persistence (favorites, overrides),
//  and deduplication classification contracts (binary duplicate, quality tiering, live vs studio).
//

import Testing
import Foundation
import AppFoundation
import GRDB
@testable import MSRU

@Suite("Library & Deduplication Invariants")
struct LibraryTests {

    @Test
    func userLibraryRepositoryTogglesFavorite() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let identityRepo = IdentityRepository(db: appDb)
        let userLibRepo = UserLibraryRepository(db: appDb)

        let recID = RecordingID("rec_fav_test")
        try await identityRepo.upsertRecording(id: recID, title: "晴天")

        // Act 1: Initial add to library with isFavorite = false
        try await userLibRepo.addLibraryEntry(recordingID: recID, isFavorite: false)
        let initialFav = try await userLibRepo.isFavorite(recordingID: recID)
        #expect(!initialFav)

        // Act 2: Set favorite to true
        try await userLibRepo.setFavorite(recordingID: recID, isFavorite: true)

        // Assert: Favorite state is persisted
        let toggledFav = try await userLibRepo.isFavorite(recordingID: recID)
        #expect(toggledFav)
        let totalCount = try await userLibRepo.totalEntriesCount()
        #expect(totalCount == 1)
    }

    @Test
    func userLibraryRepositoryPersistsMetadataOverrides() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let userLibRepo = UserLibraryRepository(db: appDb)
        let recID = RecordingID("rec_override_test")

        // Act: Set manual user override
        try await userLibRepo.setMetadataOverride(
            entityType: "recording",
            entityID: recID.rawValue,
            field: "title",
            value: "晴天 (2024 Remaster)"
        )

        // Assert: Override is stored in user_metadata_overrides table
        let overrideVal: String? = try await appDb.reader.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT override_value FROM user_metadata_overrides WHERE entity_type = ? AND entity_id = ? AND field = ?",
                arguments: ["recording", recID.rawValue, "title"]
            )
        }
        #expect(overrideVal == "晴天 (2024 Remaster)")
    }

    @Test
    func duplicateClassifierCategorizesExactBinaryMatch() {
        // Arrange: Two assets with identical SHA256 checksums
        let assetA = AudioAsset(
            id: "ast_1",
            fileURL: URL(fileURLWithPath: "/music/folder1/track.flac"),
            fileSize: 30000,
            sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            format: "FLAC"
        )
        let assetB = AudioAsset(
            id: "ast_2",
            fileURL: URL(fileURLWithPath: "/music/folder2/track.flac"),
            fileSize: 30000,
            sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            format: "FLAC"
        )

        // Act
        let result = DuplicateClassifier.classify(assetA: assetA, assetB: assetB)

        // Assert: File duplicate detected, safe to merge
        #expect(result.category == .fileDuplicate)
        #expect(result.category.isSafeToMerge)
    }

    @Test
    func duplicateClassifierCategorizesQualityDifferenceAndElectsHiResMaster() {
        // Arrange: 24/96 Master vs 16/44.1 CD rip of the same recording
        let rec = Fixtures.makeRecording(id: "rec_sunny", title: "晴天")

        let masterAsset = AudioAsset(
            id: "ast_master",
            fileURL: URL(fileURLWithPath: "/music/sunny_24_96.flac"),
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            recordingID: rec.id
        )

        let cdAsset = AudioAsset(
            id: "ast_cd",
            fileURL: URL(fileURLWithPath: "/music/sunny_16_44.flac"),
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            recordingID: rec.id
        )

        // Act
        let result = DuplicateClassifier.classify(
            assetA: cdAsset,
            recordingA: rec,
            assetB: masterAsset,
            recordingB: rec
        )

        // Assert: Quality difference detected, preferred asset is the 24/96 master
        #expect(result.category == .qualityDifference)
        #expect(result.preferredAssetID == masterAsset.id)
        #expect(!result.category.isSafeToMerge) // Never destroy lower res without user consent
    }

    @Test
    func duplicateClassifierDistinguishesStudioVsLivePerformances() {
        // Arrange: Studio recording vs Live concert capture sharing the same Work
        let work = Fixtures.makeWork(id: "wrk_sunny", title: "晴天")

        let studioRec = Recording(
            id: "rec_studio",
            title: "晴天",
            artistCredit: ArtistCredit(single: Fixtures.makeArtist()),
            workID: work.id,
            isLive: false
        )
        let liveRec = Recording(
            id: "rec_live",
            title: "晴天 (Live 2004)",
            artistCredit: ArtistCredit(single: Fixtures.makeArtist()),
            workID: work.id,
            isLive: true
        )

        let assetStudio = AudioAsset(
            id: "ast_studio",
            fileURL: URL(fileURLWithPath: "/music/studio.flac"),
            format: "FLAC",
            recordingID: studioRec.id
        )
        let assetLive = AudioAsset(
            id: "ast_live",
            fileURL: URL(fileURLWithPath: "/music/live.flac"),
            format: "FLAC",
            recordingID: liveRec.id
        )

        // Act
        let result = DuplicateClassifier.classify(
            assetA: assetStudio,
            recordingA: studioRec,
            workA: work,
            assetB: assetLive,
            recordingB: liveRec,
            workB: work
        )

        // Assert: Different performance must strictly not merge
        #expect(result.category == .differentPerformance)
        #expect(!result.category.isSafeToMerge)
        #expect(!result.category.isSameRecording)
        #expect(result.category.isSameWork)
    }
}
