//
//  AlbumsFeatureTests.swift
//  MSRUTests
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@MainActor
struct AlbumsFeatureTests {

    @Test
    func aggregateAlbumsFromTracks() {
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

        let albums = LibraryPresentationAggregator.buildAlbums(from: tracks)
        #expect(albums.count == 2)

        let jayAlbum = albums.first { $0.title == "叶惠美" }
        #expect(jayAlbum != nil)
        #expect(jayAlbum?.artist == "周杰伦")
        #expect(jayAlbum?.trackCount == 2)
        #expect(jayAlbum?.duration == 611)
        #expect(jayAlbum?.allTracks.count == 2)
        #expect(jayAlbum?.discs.count == 1)
        #expect(jayAlbum?.audioQualityBadge == "Hi-Res")

        let adeleAlbum = albums.first { $0.title == "21" }
        #expect(adeleAlbum != nil)
        #expect(adeleAlbum?.artist == "Adele")
        #expect(adeleAlbum?.trackCount == 1)
    }

    @Test
    func albumPresentationModelFormattedDuration() {
        let album = AlbumPresentationModel(
            id: "test",
            title: "Test Album",
            artist: "Test Artist",
            trackCount: 10,
            duration: 3665
        )
        #expect(album.formattedDuration == "1 hr 1 min")

        let shortAlbum = AlbumPresentationModel(
            id: "test-short",
            title: "EP",
            artist: "Test Artist",
            trackCount: 3,
            duration: 900
        )
        #expect(shortAlbum.formattedDuration == "15 min")
    }

    @Test
    func albumsFeatureProvidesValidContributions() {
        let contributions = AlbumsFeature.contributions
        #expect(contributions.sidebar.count == 1)
        #expect(contributions.sidebar.first?.id == "albums")
        #expect(contributions.sidebar.first?.group == "Library")
        #expect(contributions.sidebar.first?.title == "Albums")
        #expect(contributions.routes.first?.id == "albums")
    }
}
