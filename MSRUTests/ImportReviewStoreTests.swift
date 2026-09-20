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
}
