//
//  ArtistsFeatureTests.swift
//  MSRUTests
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
struct ArtistsFeatureTests {

    @Test
    func aggregateArtistsFromTracks() {
        let tracks = [
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/01-以父之名.flac"),
                title: "01-以父之名",
                artist: "周杰伦",
                album: "叶惠美",
                duration: 342,
                artworkData: nil
            ),
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/02-晴天.flac"),
                title: "02-晴天",
                artist: "周杰伦",
                album: "叶惠美",
                duration: 269,
                artworkData: nil
            ),
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/Rolling In The Deep.mp3"),
                title: "Rolling In The Deep",
                artist: "Adele",
                album: "21",
                duration: 228,
                artworkData: nil
            )
        ]

        let artists = LibraryPresentationAggregator.buildArtists(from: tracks)
        #expect(artists.count == 2)

        let jay = artists.first { $0.name == "周杰伦" }
        #expect(jay != nil)
        #expect(jay?.trackCount == 2)
        #expect(jay?.albumCount == 1)
        #expect(jay?.displaySubtitle == "1 album • 2 songs")

        let adele = artists.first { $0.name == "Adele" }
        #expect(adele != nil)
        #expect(adele?.trackCount == 1)
        #expect(adele?.displaySubtitle == "1 album • 1 song")
    }

    @Test
    func artistPresentationModelDisplaySubtitle() {
        let multi = ArtistPresentationModel(
            id: "1",
            name: "Artist",
            albumCount: 5,
            trackCount: 50
        )
        #expect(multi.displaySubtitle == "5 albums • 50 songs")

        let single = ArtistPresentationModel(
            id: "2",
            name: "Newbie",
            albumCount: 1,
            trackCount: 1
        )
        #expect(single.displaySubtitle == "1 album • 1 song")
    }

    @Test
    func artistsFeatureProvidesValidContributions() {
        let contributions = ArtistsFeature.contributions
        #expect(contributions.sidebar.count == 1)
        #expect(contributions.sidebar.first?.id == "artists")
        #expect(contributions.sidebar.first?.group == "Library")
        #expect(contributions.sidebar.first?.title == "Artists")
        #expect(contributions.routes.first?.id == "artists")
    }
}
