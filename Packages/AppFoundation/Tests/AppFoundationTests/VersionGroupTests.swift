//
//  VersionGroupTests.swift
//  AppFoundationTests
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation
import Testing
@testable import AppFoundation

struct VersionGroupTests {

    struct MockItem: Identifiable, Sendable, Equatable, Codable {
        let id: String
        let qualityScore: Int
        let label: String
    }

    @Test
    func versionGroupManagesPrimaryAndAlternatives() {
        let item1 = MockItem(id: "item_1", qualityScore: 100, label: "MP3 128k")
        let item2 = MockItem(id: "item_2", qualityScore: 320, label: "MP3 320k")
        let item3 = MockItem(id: "item_3", qualityScore: 960, label: "FLAC 24/96")

        var group = VersionGroup(elements: [item1, item2, item3], primaryID: "item_2")

        #expect(group.count == 3)
        #expect(group.hasAlternatives)
        #expect(group.primary == item2)
        #expect(group.alternatives == [item1, item3])

        // Explicit setPrimary
        let setOk = group.setPrimary(id: "item_3")
        #expect(setOk)
        #expect(group.primary == item3)
        #expect(group.alternatives == [item1, item2])

        // Setting non-existent ID fails
        let badSet = group.setPrimary(id: "nonexistent")
        #expect(!badSet)
        #expect(group.primary == item3)
    }

    @Test
    func selectPrimaryByComparatorChoosesOptimalElement() {
        let item1 = MockItem(id: "item_1", qualityScore: 100, label: "Low")
        let item2 = MockItem(id: "item_2", qualityScore: 500, label: "Medium")
        let item3 = MockItem(id: "item_3", qualityScore: 1000, label: "Hi-Res")

        var group = VersionGroup(elements: [item1, item2, item3])

        // Initially defaults to item1 (first element)
        #expect(group.primary?.id == "item_1")

        // Prioritize by highest quality score
        group.selectPrimary { $0.qualityScore > $1.qualityScore }
        #expect(group.primary?.id == "item_3")
    }

    @Test
    func removingPrimaryElementFallsBackSafely() {
        let item1 = MockItem(id: "item_1", qualityScore: 100, label: "First")
        let item2 = MockItem(id: "item_2", qualityScore: 200, label: "Second")

        var group = VersionGroup(elements: [item1, item2], primaryID: "item_1")
        #expect(group.primary == item1)

        // Remove designated primary -> falls back to item2
        let removed = group.remove(id: "item_1")
        #expect(removed == item1)
        #expect(group.count == 1)
        #expect(group.primary == item2)
        #expect(group.alternatives.isEmpty)

        // Remove remaining -> group becomes empty
        group.remove(id: "item_2")
        #expect(group.isEmpty)
        #expect(group.primary == nil)
    }

    @Test
    func versionGroupSupportsCodableRoundTrip() throws {
        let item1 = MockItem(id: "item_1", qualityScore: 100, label: "Item 1")
        let item2 = MockItem(id: "item_2", qualityScore: 200, label: "Item 2")
        let group = VersionGroup(elements: [item1, item2], primaryID: "item_2")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(group)
        let decoded = try decoder.decode(VersionGroup<MockItem>.self, from: data)

        #expect(decoded == group)
        #expect(decoded.primary == item2)
    }

    @Test
    func duplicateResolutionStoresMetricsAndCodable() throws {
        let resolution = DuplicateResolution<String>(
            kind: .equivalent,
            preferredID: "item_flac",
            confidence: 0.98,
            reason: "Same recording acoustID with lossless container preferred"
        )

        #expect(resolution.kind == .equivalent)
        #expect(resolution.preferredID == "item_flac")
        #expect(resolution.confidence == 0.98)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(resolution)
        let decoded = try decoder.decode(DuplicateResolution<String>.self, from: data)

        #expect(decoded == resolution)
    }
}
