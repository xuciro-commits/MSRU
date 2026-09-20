//
//  PicardAlbumLookupResolverTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct PicardAlbumLookupResolverTests {

    @Test
    func resolveAlbumClusterMatchesReleaseWithHighConfidence() async throws {
        let track1 = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Jay/01 - 以父之名.flac"),
            title: "以父之名",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 1,
            duration: 342.0
        )
        let track2 = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Jay/04 - 晴天.flac"),
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 4,
            duration: 269.0
        )

        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/Jay"),
            albumName: "叶惠美",
            tracks: [track1, track2]
        )

        let result = try await PicardAlbumLookupResolver.resolve(
            cluster: cluster,
            catalog: MusicBrainzCatalogClient.shared
        )

        #expect(result.matchedRelease != nil)
        #expect(result.matchedRelease?.releaseMBID == "rel_ye_hui_mei")
        #expect(result.confidence >= 0.90)
        #expect(result.tier == .high)
        #expect(result.trackMatches.count == 2)
        #expect(result.trackMatches[0].candidate?.title == "以父之名")
        #expect(result.trackMatches[1].candidate?.title == "晴天")
    }

    @Test
    func resolveUnidentifiedClusterReturnsLowTier() async throws {
        let track = ClusterTrackItem(
            fileURL: URL(fileURLWithPath: "/music/Unknown/mystery.wav"),
            title: "Mystery Song 12345",
            artist: "NonExistentArtist",
            album: "NonExistentAlbum",
            trackNumber: 1,
            duration: 100.0
        )

        let cluster = AlbumCluster(
            folderURL: URL(fileURLWithPath: "/music/Unknown"),
            albumName: "NonExistentAlbum",
            tracks: [track]
        )

        let result = try await PicardAlbumLookupResolver.resolve(
            cluster: cluster,
            catalog: MusicBrainzCatalogClient.shared
        )

        #expect(result.matchedRelease == nil)
        #expect(result.confidence < 0.60)
        #expect(result.tier == .low)
    }
}
