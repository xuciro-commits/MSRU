//
//  AlbumClusterTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import Testing
@testable import MSRU

@MainActor
struct AlbumClusterTests {

    @Test
    func clusterGroupsTracksByFolderAndSequentialNumber() {
        let folder = URL(fileURLWithPath: "/music/JayChou/YeHuiMei")

        let t1 = AlbumTrackItem(
            id: "t1",
            fileURL: folder.appendingPathComponent("01_InTheNameOfFather.flac"),
            title: "以父之名",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 1,
            duration: 342.0
        )
        let t2 = AlbumTrackItem(
            id: "t2",
            fileURL: folder.appendingPathComponent("02_Coward.flac"),
            title: "懦夫",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 2,
            duration: 218.0
        )
        let t3 = AlbumTrackItem(
            id: "t3",
            fileURL: folder.appendingPathComponent("04_SunnyDay.flac"),
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 3,
            duration: 269.0
        )

        let clusters = AlbumClusterer.cluster(tracks: [t2, t3, t1]) // intentionally out of order

        #expect(clusters.count == 1)
        let album = clusters[0]
        #expect(album.candidateAlbumTitle == "叶惠美")
        #expect(album.candidateArtist == "周杰伦")
        #expect(album.trackCount == 3)
        #expect(album.totalDuration == 342.0 + 218.0 + 269.0)
        #expect(album.hasSequentialTrackNumbers)

        // Tracks should be sorted sequentially 1, 2, 3
        #expect(album.tracks[0].trackNumber == 1)
        #expect(album.tracks[1].trackNumber == 2)
        #expect(album.tracks[2].trackNumber == 3)
    }

    @Test
    func clusterSeparatesTracksFromDifferentFolders() {
        let folderA = URL(fileURLWithPath: "/music/Adele/21")
        let folderB = URL(fileURLWithPath: "/music/Adele/25")

        let trackA = AlbumTrackItem(
            id: "a1",
            fileURL: folderA.appendingPathComponent("Rolling In The Deep.m4a"),
            title: "Rolling In The Deep",
            artist: "Adele",
            album: "21",
            trackNumber: 1,
            duration: 228.0
        )
        let trackB = AlbumTrackItem(
            id: "b1",
            fileURL: folderB.appendingPathComponent("Hello.m4a"),
            title: "Hello",
            artist: "Adele",
            album: "25",
            trackNumber: 1,
            duration: 295.0
        )

        let clusters = AlbumClusterer.cluster(tracks: [trackA, trackB])

        #expect(clusters.count == 2)
        let titles = Set(clusters.compactMap(\.candidateAlbumTitle))
        #expect(titles.contains("21"))
        #expect(titles.contains("25"))
    }

    @Test
    func clusterRealLocalMusicDirectorySample() {
        // Points to user's real local music path
        let realURL = URL(fileURLWithPath: "/Users/ciro/Music/Music/Media.localized/Music/Adele/21/Rolling In The Deep.m4a")

        let track = AlbumTrackItem(
            id: "real_adele_track",
            fileURL: realURL,
            title: "Rolling In The Deep",
            artist: "Adele",
            album: "21",
            trackNumber: 1,
            duration: 228.0
        )

        let clusters = AlbumClusterer.cluster(tracks: [track])
        #expect(clusters.count == 1)
        #expect(clusters[0].candidateAlbumTitle == "21")
        #expect(clusters[0].candidateArtist == "Adele")
        #expect(clusters[0].trackCount == 1)
    }
}
