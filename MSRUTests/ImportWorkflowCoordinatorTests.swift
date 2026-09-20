//
//  ImportWorkflowCoordinatorTests.swift
//  MSRUTests
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
struct ImportWorkflowCoordinatorTests {

    @Test
    func addMusicFeatureProvidesImportReviewContributions() {
        let contributions = AddMusicFeature.contributions
        #expect(contributions.sidebar.count == 1)
        #expect(contributions.sidebar.first?.id == "add-music")
        #expect(contributions.sidebar.first?.group == "Tools")
        #expect(contributions.sidebar.first?.title == "Import & Review")
        #expect(contributions.sidebar.first?.order == 200)

        let routeIDs = Set(contributions.routes.map(\.id))
        #expect(routeIDs.contains("add-music"))
        #expect(routeIDs.contains("import-review"))
    }

    @Test
    func importReviewStoreConvenienceInitFromReport() {
        let report = ImportPipelineReport(
            totalDiscovered: 12,
            autoCommittedCount: 10,
            pendingReviewClusters: [],
            unidentifiedTracks: [],
            aliasSuggestions: [
                ArtistAliasSuggestion(canonicalArtistName: "周杰伦", canonicalMBID: "mbid-jay", variantNames: ["Jay Chou"])
            ],
            duplicateDetectionsCount: 1
        )

        let store = ImportReviewStore(report: report)
        #expect(store.totalScannedCount == 12)
        #expect(store.autoAcceptedCount == 10)
        #expect(store.potentialDuplicatesCount == 1)
        #expect(store.aliasSuggestions.count == 1)
    }
}
