//
//  ExactReleaseResolverTests.swift
//  MSRUTests
//
//  Created for Acoustic Metadata Pipeline Architecture Phase 3.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct ExactReleaseResolverTests {

    @Test
    func evaluateExactReleaseYieldsHighestScoreAndHighTier() {
        let track1 = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Jay/2003 - 叶惠美/01 - 以父之名.flac"),
            title: "以父之名",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 1,
            duration: 342.0
        )
        let track2 = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Jay/2003 - 叶惠美/03 - 晴天.flac"),
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 3,
            duration: 269.0
        )

        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/Jay/2003 - 叶惠美"),
            albumName: "叶惠美",
            tracks: [track1, track2]
        )

        let candidateOriginal = ExternalReleaseMatch(
            releaseMBID: "rel_original_2003",
            title: "叶惠美",
            artist: "周杰伦",
            date: "2003-07-31",
            country: "TW",
            trackCount: 2,
            tracks: [
                ExternalTrackMatch(position: 1, title: "以父之名", recordingMBID: "rec_father", duration: 342.0),
                ExternalTrackMatch(position: 3, title: "晴天", recordingMBID: "rec_sunny", duration: 269.0)
            ]
        )

        let candidateCompilation = ExternalReleaseMatch(
            releaseMBID: "rel_compilation_2007",
            title: "周杰伦精选集",
            artist: "周杰伦",
            date: "2007-10-01",
            country: "TW",
            trackCount: 20,
            tracks: [
                ExternalTrackMatch(position: 14, title: "晴天", recordingMBID: "rec_sunny", duration: 269.0)
            ]
        )

        let ranked = ExactReleaseResolver.rankCandidates(
            cluster: cluster,
            candidates: [candidateCompilation, candidateOriginal],
            baseAcoustIDScore: 0.98
        )

        #expect(ranked.count == 2)
        #expect(ranked[0].release.releaseMBID == "rel_original_2003")
        #expect(ranked[0].totalScore > ranked[1].totalScore)
        #expect(ranked[0].tier == .high)
        #expect(ranked[0].totalScore >= 0.92)
    }

    @Test
    func folderYearContextBoostsMatchingReleaseEdition() {
        let track1 = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Rock/2023 - Live Edition/01 - Track.flac"),
            title: "Track One",
            artist: "Band",
            album: "Live Edition",
            trackNumber: 1,
            duration: 200.0
        )

        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/Rock/2023 - Live Edition"),
            albumName: "Live Edition",
            tracks: [track1]
        )

        let release2010 = ExternalReleaseMatch(
            releaseMBID: "rel_2010",
            title: "Live Edition",
            artist: "Band",
            date: "2010-01-01",
            trackCount: 1,
            tracks: [ExternalTrackMatch(position: 1, title: "Track One", duration: 200.0)]
        )

        let release2023 = ExternalReleaseMatch(
            releaseMBID: "rel_2023",
            title: "Live Edition",
            artist: "Band",
            date: "2023-05-12",
            trackCount: 1,
            tracks: [ExternalTrackMatch(position: 1, title: "Track One", duration: 200.0)]
        )

        let ranked = ExactReleaseResolver.rankCandidates(
            cluster: cluster,
            candidates: [release2010, release2023],
            baseAcoustIDScore: 0.95
        )

        #expect(ranked.count == 2)
        // 2023 release should rank first because of folder year 2023 alignment
        #expect(ranked[0].release.releaseMBID == "rel_2023")
    }
}
