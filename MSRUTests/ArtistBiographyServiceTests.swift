//
//  ArtistBiographyServiceTests.swift
//  MSRUTests
//

import Testing
import Foundation
@testable import MSRU

@MainActor
struct ArtistBiographyServiceTests {

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
}
