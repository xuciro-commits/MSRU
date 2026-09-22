//
//  MetadataResolutionTests.swift
//  MSRUTests
//
//  Canonical metadata resolution tests protecting filename heuristic parsing,
//  generic folder filtering, and Picard weighted candidate matching.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
@Suite("Metadata Resolution & Matching Invariants")
struct MetadataResolutionTests {

    @Test
    func fileNameHeuristicParserExtractsStructuredClues() {
        // Test 1: "Artist - Title" pattern
        let url1 = URL(fileURLWithPath: "/music/周杰伦 - 晴天.flac")
        let parsed1 = FileNameHeuristicParser.parse(fileURL: url1)
        #expect(parsed1.artist == "周杰伦")
        #expect(parsed1.title == "晴天")

        // Test 2: "TrackNumber. Title" pattern
        let url2 = URL(fileURLWithPath: "/music/04. 晴天.mp3")
        let parsed2 = FileNameHeuristicParser.parse(fileURL: url2)
        #expect(parsed2.trackNumber == 4)
        #expect(parsed2.title == "晴天")

        // Test 3: "TrackNumber - Artist - Title" pattern
        let url3 = URL(fileURLWithPath: "/music/04 - Jay Chou - Sunny Day.wav")
        let parsed3 = FileNameHeuristicParser.parse(fileURL: url3)
        #expect(parsed3.artist == "Jay Chou")
        #expect(parsed3.trackNumber == 4)
        #expect(parsed3.title == "Sunny Day")
    }

    @Test
    func genericFolderClassificationDistinguishesRealAlbumsFromGenericFolders() {
        // Assert generic folders are recognized
        #expect(FileNameHeuristicParser.isGenericFolderName("Music"))
        #expect(FileNameHeuristicParser.isGenericFolderName("Unsorted"))
        #expect(FileNameHeuristicParser.isGenericFolderName("01-Download"))
        #expect(FileNameHeuristicParser.isGenericFolderName("新建文件夹"))
        #expect(FileNameHeuristicParser.isGenericFolderName("71-音乐库"))

        // Assert legitimate short/numbered album titles are preserved
        #expect(!FileNameHeuristicParser.isGenericFolderName("21"))
        #expect(!FileNameHeuristicParser.isGenericFolderName("1989"))
        #expect(!FileNameHeuristicParser.isGenericFolderName("范特西"))
        #expect(!FileNameHeuristicParser.isGenericFolderName("Abbey Road"))
    }

    @Test
    func matchScorerAssignsHighConfidenceToExactCatalogMatches() {
        // Arrange
        let query = MatchQuery(
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            duration: 269.0,
            trackNumber: 4,
            year: 2003
        )
        let candidate = CatalogTrackCandidate(
            trackMBID: "rec_sunny_day_mbid",
            releaseMBID: "rel_ye_hui_mei_mbid",
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            duration: 269.0,
            trackNumber: 4,
            year: 2003
        )

        // Act
        let score = MatchScorer.evaluate(query: query, against: candidate)

        // Assert: Exact matches must achieve high tier and confidence >= 0.85
        #expect(score.tier == .high)
        #expect(score.confidence >= 0.85)
    }

    @Test
    func matchScorerDegradesConfidenceOnMismatchedArtistAndDuration() {
        // Arrange
        let query = MatchQuery(
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            duration: 269.0
        )
        let mismatchedCandidate = CatalogTrackCandidate(
            trackMBID: "rec_other",
            title: "晴天",
            artist: "完全不同歌手",
            album: "其他专辑",
            duration: 180.0 // 89s difference
        )

        // Act
        let score = MatchScorer.evaluate(query: query, against: mismatchedCandidate)

        // Assert: Divergent artist and duration drops score below high tier
        #expect(score.tier != .high)
        #expect(score.confidence < 0.65)
    }

    @Test
    func picardAlbumLookupResolverResolvesTracksAgainstCatalogRelease() async throws {
        // Arrange
        let track = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Jay/04.晴天.flac"),
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 4,
            duration: 269.0
        )
        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/Jay"),
            candidateAlbumTitle: "叶惠美",
            candidateArtist: "周杰伦",
            tracks: [track]
        )

        let release = ExternalReleaseMatch(
            releaseMBID: "rel_ye_mbid",
            title: "叶惠美",
            artist: "周杰伦",
            date: "2003",
            trackCount: 11,
            tracks: [
                ExternalTrackMatch(
                    position: 4,
                    title: "晴天",
                    recordingMBID: "rec_sunny_mbid",
                    duration: 269.0
                )
            ]
        )

        let fakeCatalog = FakeCatalogService()
        fakeCatalog.searchResults = [(artist: "周杰伦", album: "叶惠美", results: [release])]
        fakeCatalog.releases[release.releaseMBID] = release

        // Act
        let result = try await PicardAlbumLookupResolver.resolve(cluster: cluster, catalog: fakeCatalog)

        // Assert: Resolves high tier with matching release and track MBID
        #expect(result.matchedRelease?.releaseMBID == "rel_ye_mbid")
        #expect(result.tier == .high)
        let trackMatch = result.trackMatches.first
        #expect(trackMatch?.candidate?.trackMBID == "rec_sunny_mbid")
        #expect(trackMatch?.candidate?.title == "晴天")
        #expect(trackMatch?.candidate?.album == "叶惠美")
    }
}
