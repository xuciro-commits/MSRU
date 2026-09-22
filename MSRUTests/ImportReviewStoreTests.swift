//
//  ImportReviewStoreTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct ImportReviewStoreTests {

    private func makeSampleStore() -> ImportReviewStore {
        let dummyTrack = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Jay/04 - 晴天.flac"),
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 4,
            duration: 269.0
        )
        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/Jay"),
            albumName: "叶惠美",
            tracks: [dummyTrack]
        )
        let releaseMatch = ExternalReleaseMatch(
            releaseMBID: "rel_ye_hui_mei",
            title: "叶惠美",
            artist: "周杰伦",
            date: "2003",
            trackCount: 11
        )
        let clusterResult = AlbumClusterLookupResult(
            cluster: cluster,
            matchedRelease: releaseMatch,
            confidence: 0.85,
            tier: .medium,
            trackMatches: [
                ClusterTrackMatch(
                    localTrack: dummyTrack,
                    candidate: CatalogTrackCandidate(trackMBID: "rec_sunny", title: "晴天", artist: "周杰伦"),
                    score: WeightedScoreResult(confidence: 0.85, tier: .medium, components: [])
                )
            ]
        )
        let suggestion = ArtistAliasSuggestion(
            canonicalArtistName: "周杰伦",
            canonicalMBID: "artist_jay_chou",
            variantNames: ["Jay Chou", "周杰倫"]
        )

        return ImportReviewStore(
            totalScannedCount: 100,
            autoAcceptedCount: 80,
            pendingReviewClusters: [clusterResult],
            unidentifiedTracks: [],
            potentialDuplicatesCount: 2,
            aliasSuggestions: [suggestion]
        )
    }

    @Test
    func filteringAndSearchingPendingClusters() {
        let store = makeSampleStore()
        #expect(store.filteredClusters.count == 1)

        store.searchText = "叶惠美"
        #expect(store.filteredClusters.count == 1)

        store.searchText = "NonExistentQuery"
        #expect(store.filteredClusters.isEmpty)

        store.searchText = ""
        store.selectedFilter = .unidentified
        #expect(store.filteredClusters.isEmpty)
    }

    @Test
    func acceptSelectedMatchesIncrementsAcceptedCount() {
        let store = makeSampleStore()
        let clusterID = store.pendingReviewClusters[0].id
        store.selectedClusterIDs = [clusterID]

        store.acceptSelectedMatches()
        #expect(store.autoAcceptedCount == 81)
        #expect(store.pendingReviewClusters.isEmpty)
        #expect(store.selectedClusterIDs.isEmpty)
    }

    @Test
    func mergeAliasSuggestionRemovesCard() {
        let store = makeSampleStore()
        let suggestionID = store.aliasSuggestions[0].id

        store.mergeAliasSuggestion(id: suggestionID)
        #expect(store.aliasSuggestions.isEmpty)
    }

    @Test
    func discardUnconfirmedClearsPending() {
        let store = makeSampleStore()
        store.discardUnconfirmed()

        #expect(store.pendingReviewClusters.isEmpty)
        #expect(store.selectedClusterIDs.isEmpty)
    }

    @Test
    func candidateReleaseAlbumOverridesGenericLocalFolderAlbum() async {
        let dummyTrack = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/71-音乐库/2234.mp3"),
            title: "2234",
            artist: "张学友",
            album: "71-音乐库",
            trackNumber: 1,
            duration: 258.0
        )
        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/71-音乐库"),
            candidateAlbumTitle: "71-音乐库",
            candidateArtist: "张学友",
            tracks: [dummyTrack]
        )
        let releaseMatch = ExternalReleaseMatch(
            releaseMBID: "rel_bai_yin_shi_dai",
            title: "白银时代",
            artist: "张学友",
            date: "2004",
            trackCount: 10
        )
        let clusterResult = AlbumClusterLookupResult(
            cluster: cluster,
            matchedRelease: releaseMatch,
            confidence: 0.95,
            tier: .high,
            trackMatches: [
                ClusterTrackMatch(
                    localTrack: dummyTrack,
                    candidate: CatalogTrackCandidate(trackMBID: "rec_faraway", title: "遥远的她", artist: "张学友", album: "白银时代"),
                    score: WeightedScoreResult(confidence: 0.95, tier: .high, components: [])
                )
            ]
        )

        let store = ImportReviewStore(
            totalScannedCount: 1,
            autoAcceptedCount: 0,
            pendingReviewClusters: [clusterResult],
            unidentifiedTracks: []
        )
        store.selectedClusterIDs = [clusterResult.id]

        // Test 1: acceptSelectedMatches produces LocalTrack with album "白银时代", not "71-音乐库"
        let acceptedTracks = store.acceptSelectedMatches()
        #expect(acceptedTracks.count == 1)
        #expect(acceptedTracks[0].title == "遥远的她")
        #expect(acceptedTracks[0].artist == "张学友")
        #expect(acceptedTracks[0].album == "白银时代")
        #expect(acceptedTracks[0].album != "71-音乐库")

        // Test 2: commitSelectedMatches also writes album "白银时代"
        let store2 = ImportReviewStore(
            totalScannedCount: 1,
            autoAcceptedCount: 0,
            pendingReviewClusters: [clusterResult],
            unidentifiedTracks: []
        )
        store2.selectedClusterIDs = [clusterResult.id]
        let committedTracks = await store2.commitSelectedMatches(writePhysicalTags: false, exportCompanionCover: false)
        #expect(committedTracks.count == 1)
        #expect(committedTracks[0].album == "白银时代")
        #expect(committedTracks[0].album != "71-音乐库")

        // Test 3: importAsOriginalFiles clears generic folder album "71-音乐库"
        let store3 = ImportReviewStore(
            totalScannedCount: 1,
            autoAcceptedCount: 0,
            pendingReviewClusters: [clusterResult],
            unidentifiedTracks: []
        )
        store3.selectedClusterIDs = [clusterResult.id]
        let originalTracks = store3.importAsOriginalFiles()
        #expect(originalTracks.count == 1)
        #expect(originalTracks[0].album == nil)
    }
}
