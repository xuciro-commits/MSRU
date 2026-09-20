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
        #expect(contributions.sidebar.first?.group == "工具")
        #expect(contributions.sidebar.first?.title == "导入与审核")
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

    @Test
    func nestedFolderAudioDiscoveryFiltersNonAudioFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let artistFolder = tempDir.appendingPathComponent("男歌手/王力宏", isDirectory: true)
        try FileManager.default.createDirectory(at: artistFolder, withIntermediateDirectories: true)

        let wavTrack = artistFolder.appendingPathComponent("王力宏-你不知道的事.wav")
        let flacTrack = artistFolder.appendingPathComponent("王力宏-爱错.flac")
        let dsStore = artistFolder.appendingPathComponent(".DS_Store")
        let textFile = artistFolder.appendingPathComponent("info.txt")

        try "fake wav".data(using: .utf8)?.write(to: wavTrack)
        try "fake flac".data(using: .utf8)?.write(to: flacTrack)
        try "ds_store".data(using: .utf8)?.write(to: dsStore)
        try "info".data(using: .utf8)?.write(to: textFile)

        #expect(LocalAudioFormatSupport.supports(wavTrack))
        #expect(LocalAudioFormatSupport.supports(flacTrack))
        #expect(!LocalAudioFormatSupport.supports(dsStore))
        #expect(!LocalAudioFormatSupport.supports(textFile))

        // Test recursive folder enumeration
        var discoveredAudio: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if LocalAudioFormatSupport.supports(fileURL) {
                    discoveredAudio.append(fileURL)
                }
            }
        }

        #expect(discoveredAudio.count == 2)
        let filenames = Set(discoveredAudio.map(\.lastPathComponent))
        #expect(filenames.contains("王力宏-你不知道的事.wav"))
        #expect(filenames.contains("王力宏-爱错.flac"))
    }

    @Test
    func importReviewStoreGeneratesLocalTracksWithOriginalInPlaceURLs() {
        let originalURL = URL(fileURLWithPath: "/Volumes/MusicNAS/03 音乐资源/音乐/1.歌曲/男歌手/王力宏/王力宏-你不知道的事.wav")
        let clusterItem = ClusterTrackItem(
            fileURL: originalURL,
            title: "你不知道的事",
            artist: "王力宏",
            album: "十八般武艺",
            trackNumber: 1,
            duration: 278.0
        )

        let cluster = AlbumCluster(
            folderURL: originalURL.deletingLastPathComponent(),
            albumName: "十八般武艺",
            tracks: [clusterItem]
        )

        let clusterResult = AlbumClusterLookupResult(
            cluster: cluster,
            matchedRelease: nil,
            confidence: 0.0,
            tier: .low,
            trackMatches: [
                ClusterTrackMatch(
                    localTrack: clusterItem,
                    candidate: nil,
                    score: WeightedScoreResult(confidence: 0.0, tier: .low, components: [])
                )
            ]
        )

        let store = ImportReviewStore(
            totalScannedCount: 1,
            autoAcceptedCount: 0,
            pendingReviewClusters: [clusterResult],
            unidentifiedTracks: [clusterItem]
        )

        #expect(store.filteredClusters.count == 1)
        #expect(store.selectedClusterIDs.contains(clusterResult.id))

        let importedTracks = store.importAsOriginalFiles()
        #expect(importedTracks.count == 1)
        let track = importedTracks[0]

        // Strict In-Place verification: fileURL must match original exactly, zero alteration
        #expect(track.fileURL == originalURL)
        #expect(track.title == "你不知道的事")
        #expect(track.artist == "王力宏")
        #expect(track.album == "十八般武艺")
        #expect(track.duration == 278.0)
    }

    @Test
    func localLibraryStoreAddTracksPreservesOriginalURLs() async {
        let memoryRepo = FileLocalLibraryRepository()
        let store = LocalLibraryStore(repository: memoryRepo)

        let originalURL = URL(fileURLWithPath: "/Volumes/Music/王力宏-爱错.flac")
        let track = LocalTrack(
            fileURL: originalURL,
            title: "爱错",
            artist: "王力宏",
            album: "心中的日月",
            duration: 240.0,
            artworkData: nil
        )

        await store.addTracks([track])
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.fileURL == originalURL)
        #expect(store.tracks.first?.title == "爱错")
        #expect(store.tracks.first?.artist == "王力宏")
    }
}
