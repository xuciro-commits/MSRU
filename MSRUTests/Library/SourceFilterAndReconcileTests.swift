//
//  SourceFilterAndReconcileTests.swift
//  MSRUTests
//
//  Tests for multi-source database queries, source filtering, and deterministic ID separation.
//

import Foundation
import Testing
import AppFoundation
import MusicDomain
import GRDB
import MusicLibrary
import MusicPlayback
@testable import MSRU

@Suite("Multi-Source Query & Identity Invariants")
struct SourceFilterAndReconcileTests {

    @Test("DeterministicID keeps source-scoped identities strictly decoupled from local canonical entities")
    func deterministicIDSeparation() {
        let sourceID = SourceID("src_zspace_pro")
        let itemID = "track_sub_456"

        let sourceRecID = DeterministicID.sourceRecording(sourceID: sourceID, itemID: itemID)
        let localRecID = DeterministicID.recording(title: "Hotel California", artist: "Eagles")

        #expect(sourceRecID.rawValue != localRecID.rawValue)
        #expect(sourceRecID.rawValue.hasPrefix("rec_"))
        #expect(sourceRecID == DeterministicID.sourceRecording(sourceID: sourceID, itemID: itemID))
        #expect(sourceRecID != DeterministicID.sourceRecording(sourceID: SourceID("other_src"), itemID: itemID))

        let sourceRelID = DeterministicID.sourceRelease(sourceID: sourceID, itemID: "album_789")
        let localRelID = DeterministicID.release(artist: "Eagles", title: "Hotel California")
        #expect(sourceRelID.rawValue != localRelID.rawValue)

        let sourceArtID = DeterministicID.sourceArtist(sourceID: sourceID, itemID: "artist_101")
        let localArtID = DeterministicID.artist(name: "Eagles")
        #expect(sourceArtID.rawValue != localArtID.rawValue)
    }

    @Test("SourceFilterItem correctly handles nil and populated sourceIDs")
    func sourceFilterItemProperties() {
        let allItem = SourceFilterItem(id: nil, displayName: "All Sources", count: 42)
        #expect(allItem.sourceID == nil)
        #expect(allItem.id == "__all__")
        #expect(allItem.count == 42)

        let localItem = SourceFilterItem(id: "local", displayName: "Local Files", count: 20)
        #expect(localItem.sourceID == "local")
        #expect(localItem.id == "local")
        #expect(localItem.count == 20)
    }

    @Test("LibraryQueryEngine filters results by sourceFilter")
    func libraryQueryEngineSourceFiltering() async throws {
        let db = try TestDatabase.makeEphemeral()
        let queryEngine = LibraryQueryEngine(db: db)
        let identityRepo = IdentityRepository(db: db)
        let assetRepo = AssetRepository(db: db)

        // 1. Seed Sources: Local and Subsonic
        let localSourceID = SourceID("local")
        try await TestDatabase.seedSource(in: db, id: localSourceID, name: "Local Files", uri: "/Users/music")

        let remoteSourceID = SourceID("src_nas_zspace")
        try await SourceRepository(db: db).insertOrUpdate(Source(
            id: remoteSourceID,
            sourceType: .networkFolder,
            uri: "http://nas.local:4533",
            displayName: "极空间 NAS",
            capabilities: .networkFolderDefault,
            isEnabled: true
        ))

        // 2. Seed Local Track
        let localRecID = DeterministicID.recording(title: "Track One", artist: "Artist A")
        let localRelID = DeterministicID.release(artist: "Artist A", title: "Album One")
        let localRelGroupID = DeterministicID.releaseGroup(artist: "Artist A", title: "Album One")
        let localArtID = DeterministicID.artist(name: "Artist A")
        let localTrackID = DeterministicID.releaseTrack(releaseID: localRelID, medium: 1, track: 1)
        let localAstID = DeterministicID.asset(sourceID: localSourceID, relativePath: "track1.flac")

        try await identityRepo.batchUpsertEntities(
            artists: [(id: localArtID, name: "Artist A")],
            recordings: [(id: localRecID, title: "Track One", duration: 180.0)],
            releaseGroups: [(id: localRelGroupID, title: "Album One")],
            releases: [(id: localRelID, releaseGroupID: localRelGroupID, title: "Album One", year: 2020, artworkAssetID: nil)],
            releaseTracks: [(id: localTrackID, releaseID: localRelID, trackNumber: 1, title: "Track One", duration: 180.0, recordingID: localRecID)],
            artistCredits: [(artistID: localArtID, entityType: "recording", entityID: localRecID.rawValue)]
        )

        let localAsset = PersistedAssetRecord(
            id: localAstID,
            sourceID: localSourceID,
            relativePath: "track1.flac",
            fileSize: 10_000_000,
            mtime: 1000,
            format: "FLAC",
            bitrateKbps: 900,
            duration: 180.0,
            recordingID: localRecID
        )
        try await assetRepo.batchUpsert([localAsset])

        // 3. Seed Remote Subsonic Track
        let remoteRecID = DeterministicID.sourceRecording(sourceID: remoteSourceID, itemID: "sub_rec_99")
        let remoteRelID = DeterministicID.sourceRelease(sourceID: remoteSourceID, itemID: "sub_alb_99")
        let remoteRelGroupID = DeterministicID.sourceReleaseGroup(sourceID: remoteSourceID, itemID: "sub_alb_99")
        let remoteArtID = DeterministicID.sourceArtist(sourceID: remoteSourceID, itemID: "Artist B")
        let remoteTrackID = DeterministicID.releaseTrack(releaseID: remoteRelID, medium: 1, track: 1)
        let remoteAstID = DeterministicID.asset(sourceID: remoteSourceID, relativePath: "sub_item_99")

        try await identityRepo.batchUpsertEntities(
            artists: [(id: remoteArtID, name: "Artist B")],
            recordings: [(id: remoteRecID, title: "Track Two", duration: 210.0)],
            releaseGroups: [(id: remoteRelGroupID, title: "Album Two")],
            releases: [(id: remoteRelID, releaseGroupID: remoteRelGroupID, title: "Album Two", year: 2022, artworkAssetID: nil)],
            releaseTracks: [(id: remoteTrackID, releaseID: remoteRelID, trackNumber: 1, title: "Track Two", duration: 210.0, recordingID: remoteRecID)],
            artistCredits: [(artistID: remoteArtID, entityType: "recording", entityID: remoteRecID.rawValue)]
        )

        let remoteAsset = PersistedAssetRecord(
            id: remoteAstID,
            sourceID: remoteSourceID,
            relativePath: "sub_item_99",
            fileSize: 5_000_000,
            mtime: 2000,
            format: "MP3",
            bitrateKbps: 320,
            duration: 210.0,
            recordingID: remoteRecID
        )
        try await assetRepo.batchUpsert([remoteAsset])

        // 4. Test Query without filter (All Sources)
        let allSpec = QuerySpec(query: "", sourceFilter: nil)
        let allResults = try await queryEngine.fetchRowSummaries(spec: allSpec)
        #expect(allResults.count == 2)

        // 5. Test Query with local filter
        let localSpec = QuerySpec(query: "", sourceFilter: "local")
        let localResults = try await queryEngine.fetchRowSummaries(spec: localSpec)
        #expect(localResults.count == 1)
        #expect(localResults.first?.title == "Track One")

        // 6. Test Query with remote NAS filter
        let remoteSpec = QuerySpec(query: "", sourceFilter: "src_nas_zspace")
        let remoteResults = try await queryEngine.fetchRowSummaries(spec: remoteSpec)
        #expect(remoteResults.count == 1)
        #expect(remoteResults.first?.title == "Track Two")

        // 7. Test fetchAvailableSources (Remote count is nil, All count is nil when remote present)
        let availableSources = try await queryEngine.fetchAvailableSources(for: "recording")
        #expect(availableSources.count == 3) // All, Local Files, 极空间 NAS
        let allFilter = availableSources.first(where: { $0.sourceID == nil })
        #expect(allFilter?.count == nil)

        let localFilter = availableSources.first(where: { SourceID.isLocalSourceID($0.sourceID) })
        #expect(localFilter?.count == 1)

        let remoteFilter = availableSources.first(where: { $0.sourceID == "src_nas_zspace" })
        #expect(remoteFilter?.count == nil)
    }
}
