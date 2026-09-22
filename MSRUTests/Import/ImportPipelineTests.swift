//
//  ImportPipelineTests.swift
//  MSRUTests
//
//  Canonical import pipeline tests protecting import boundary,
//  directory clustering, generic folder sanitization, and review store contracts.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
@Suite("Import Pipeline & Clustering Contracts")
struct ImportPipelineTests {

    @Test
    func emptyInputProducesZeroDiscoveredWithoutError() async throws {
        // Arrange
        let fakeFingerprinter = FakeFingerprinter()
        let fakeCatalog = FakeCatalogService()
        let pipeline = ImportPipeline(fingerprinter: fakeFingerprinter, catalog: fakeCatalog)

        // Act
        let report = try await pipeline.process(audioURLs: [])

        // Assert
        #expect(report.totalDiscovered == 0)
        #expect(report.autoCommittedCount == 0)
        #expect(report.pendingReviewClusters.isEmpty)
        #expect(report.unidentifiedTracks.isEmpty)
    }

    @Test
    func validAudioFixtureClusteredByFolder() async throws {
        // Arrange: Generate two deterministic WAV fixtures in a specific album directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestAlbum_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wav1 = tempDir.appendingPathComponent("01. Track One.wav")
        let wav2 = tempDir.appendingPathComponent("02. Track Two.wav")
        let sourceWav = try Fixtures.createDeterministicWAV(durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: sourceWav.deletingLastPathComponent()) }

        try FileManager.default.copyItem(at: sourceWav, to: wav1)
        try FileManager.default.copyItem(at: sourceWav, to: wav2)

        let fakeFingerprinter = FakeFingerprinter()
        let fakeCatalog = FakeCatalogService()
        let pipeline = ImportPipeline(fingerprinter: fakeFingerprinter, catalog: fakeCatalog)

        // Act
        let report = try await pipeline.process(audioURLs: [wav1, wav2])

        // Assert: 2 discovered, grouped into 1 album cluster
        #expect(report.totalDiscovered == 2)
        #expect(report.pendingReviewClusters.count == 1)
        let cluster = report.pendingReviewClusters.first?.cluster
        #expect(cluster?.tracks.count == 2)
        #expect(cluster?.folderURL?.lastPathComponent == tempDir.lastPathComponent)
    }

    @Test
    func genericFolderNamesAreSanitizedAndRejectedAsAlbum() async throws {
        // Arrange: Create a file inside a generic folder "71-音乐库" in an isolated container
        let testContainer = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestGeneric_\(UUID().uuidString)", isDirectory: true)
        let genericDir = testContainer
            .appendingPathComponent("71-音乐库", isDirectory: true)
        try FileManager.default.createDirectory(at: genericDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testContainer) }

        let wavFile = genericDir.appendingPathComponent("周杰伦 - 晴天.wav")
        let sourceWav = try Fixtures.createDeterministicWAV(durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: sourceWav.deletingLastPathComponent()) }
        try FileManager.default.copyItem(at: sourceWav, to: wavFile)

        let fakeFingerprinter = FakeFingerprinter()
        let fakeCatalog = FakeCatalogService()
        let pipeline = ImportPipeline(fingerprinter: fakeFingerprinter, catalog: fakeCatalog)

        // Act
        let report = try await pipeline.process(audioURLs: [wavFile])

        // Assert: Cluster candidateAlbumTitle must NOT be "71-音乐库"
        #expect(report.totalDiscovered == 1)
        let cluster = report.pendingReviewClusters.first?.cluster
        #expect(cluster?.candidateAlbumTitle != "71-音乐库")
        if let alb = cluster?.candidateAlbumTitle, !alb.isEmpty {
            #expect(!FileNameHeuristicParser.isGenericFolderName(alb))
        }
    }

    @Test
    func importReviewStoreAcceptSelectedMatchesOverridesGenericFolderAlbum() {
        // Arrange
        let dummyTrack = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/71-音乐库/01.mp3"),
            title: "晴天",
            artist: "周杰伦",
            album: "71-音乐库",
            trackNumber: 1,
            duration: 269.0
        )
        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/71-音乐库"),
            candidateAlbumTitle: "71-音乐库",
            candidateArtist: "周杰伦",
            tracks: [dummyTrack]
        )
        let matchedRelease = ExternalReleaseMatch(
            releaseMBID: "rel_ye_hui_mei_mbid",
            title: "叶惠美",
            artist: "周杰伦",
            date: "2003",
            trackCount: 11
        )
        let clusterResult = AlbumClusterLookupResult(
            cluster: cluster,
            matchedRelease: matchedRelease,
            confidence: 0.95,
            tier: .high,
            trackMatches: [
                ClusterTrackMatch(
                    localTrack: dummyTrack,
                    candidate: CatalogTrackCandidate(
                        trackMBID: "rec_sunny_mbid",
                        title: "晴天",
                        artist: "周杰伦",
                        album: "叶惠美"
                    ),
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

        // Act: Accept selected matches
        let accepted = store.acceptSelectedMatches()

        // Assert: Resulting local track resolves to "叶惠美", never generic "71-音乐库"
        #expect(accepted.count == 1)
        #expect(accepted[0].title == "晴天")
        #expect(accepted[0].artist == "周杰伦")
        #expect(accepted[0].album == "叶惠美")
        #expect(accepted[0].album != "71-音乐库")
    }
}
