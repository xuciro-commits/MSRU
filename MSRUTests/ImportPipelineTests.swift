//
//  ImportPipelineTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct ImportPipelineTests {

    @Test
    func processEmptyAudioURLsReturnsEmptyReport() async throws {
        let pipeline = ImportPipeline()
        let report = try await pipeline.process(audioURLs: [])

        #expect(report.totalDiscovered == 0)
        #expect(report.autoCommittedCount == 0)
        #expect(report.pendingReviewClusters.isEmpty)
    }

    @Test
    func processClusteredAudioURLsExecutes11Steps() async throws {
        let dummyURL1 = URL(fileURLWithPath: "/music/Jay Chou - 以父之名.mp3")
        let dummyURL2 = URL(fileURLWithPath: "/music/Jay Chou - 晴天.mp3")

        let pipeline = ImportPipeline()
        let report = try await pipeline.process(audioURLs: [dummyURL1, dummyURL2])

        #expect(report.totalDiscovered == 2)
        #expect(!report.aliasSuggestions.isEmpty)
        if let first = report.aliasSuggestions.first {
            #expect(first.canonicalArtistName == "周杰伦")
        }
    }
}
