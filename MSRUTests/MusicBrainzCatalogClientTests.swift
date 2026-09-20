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
}
