//
//  MusicBrainzCatalogClientTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct MusicBrainzCatalogClientTests {

    @Test
    func lookupReleaseByAuthoritativeMBID() async throws {
        let client = MusicBrainzCatalogClient(seedDefaultData: true)
        let release = try await client.lookupRelease(releaseMBID: "rel_ye_hui_mei")

        #expect(release != nil)
        #expect(release?.title == "叶惠美")
        #expect(release?.artist == "周杰伦")
        #expect(release?.tracks.count == 3)
    }

    @Test
    func searchReleasesByArtistAndAlbum() async throws {
        let client = MusicBrainzCatalogClient(seedDefaultData: true)
        let results = try await client.searchReleases(artist: "Adele", album: "21")

        #expect(!results.isEmpty)
        #expect(results[0].releaseMBID == "rel_adele_21")
        #expect(results[0].artist == "Adele")
    }

    @Test
    func fetchArtistAliasesReturnsMultilingualNames() async throws {
        let client = MusicBrainzCatalogClient(seedDefaultData: true)
        let aliases = try await client.fetchArtistAliases(artistMBID: "artist_jay_chou")

        #expect(aliases.count >= 3)
        let names = Set(aliases.map { $0.name })
        #expect(names.contains("Jay Chou"))
        #expect(names.contains("周杰倫"))
        #expect(names.contains("周杰伦"))
    }

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

    @Test
    func cachedBiographyIsReturnedImmediately() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bioRecord = ArtistBiographyRecord(
            artistName: "Test Artist",
            summary: "This is a cached summary of Test Artist.",
            sourceURL: URL(string: "https://zh.wikipedia.org/wiki/Test_Artist"),
            thumbnailURL: nil,
            genres: ["Pop", "Rock"],
            lifeSpan: "1980 - 至今",
            country: "CN"
        )

        let cacheFile = tempDir.appendingPathComponent("Test Artist.json")
        let data = try JSONEncoder().encode(bioRecord)
        try data.write(to: cacheFile)

        let service = ArtistBiographyService(cacheDirectory: tempDir)
        let fetched = await service.fetchBiography(artistName: "Test Artist")

        let unwrapped = try #require(fetched)
        #expect(unwrapped.artistName == "Test Artist")
        #expect(unwrapped.summary == "This is a cached summary of Test Artist.")
        #expect(unwrapped.genres == ["Pop", "Rock"])
        #expect(unwrapped.lifeSpan == "1980 - 至今")
        #expect(unwrapped.country == "CN")
    }

    @Test
    func unknownArtistReturnsNil() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = ArtistBiographyService(cacheDirectory: tempDir)
        let fetched = await service.fetchBiography(artistName: "Unknown Artist")
        #expect(fetched == nil)
    }

    @Test
    func cleanAlbumTitleStripsMediaSuffixes() {
        #expect(MusicBrainzCatalogClient.cleanAlbumTitle("By Heart - SACD") == "By Heart")
        #expect(MusicBrainzCatalogClient.cleanAlbumTitle("Fantasy [SACD]") == "Fantasy")
        #expect(MusicBrainzCatalogClient.cleanAlbumTitle("21 (Deluxe Edition)") == "21")
        #expect(MusicBrainzCatalogClient.cleanAlbumTitle("Greatest Hits [FLAC 24-96]") == "Greatest Hits")
        #expect(MusicBrainzCatalogClient.cleanAlbumTitle("The Wall - Remastered") == "The Wall")
    }

    @Test
    func resolveRemoteArtworkForPriscillaChanByHeart() async throws {
        let resolved = await LocalArtworkExtractor.resolveRemoteArtwork(
            artist: "陈慧娴",
            album: "By Heart - SACD",
            title: "Snowflake"
        )

        let unwrapped = try #require(resolved)
        #expect(unwrapped.canonicalAlbum?.contains("By Heart") == true)
        #expect(LocalArtworkExtractor.isValidImageData(unwrapped.data))
    }
}

