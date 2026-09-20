//
//  TrackMetadataOverlayTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 1.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct TrackMetadataOverlayTests {

    @Test
    func initializeFromLocalTrackSetsRawLayerOnly() {
        let localTrack = LocalTrack(
            fileURL: URL(fileURLWithPath: "/music/04 晴天.mp3"),
            title: "04 晴天",
            artist: "Jay Chou",
            album: "叶惠美",
            duration: 269.0,
            artworkData: nil
        )

        let overlay = TrackMetadataOverlay(from: localTrack, assetID: "asset_123")

        #expect(overlay.id == localTrack.id)
        #expect(overlay.assetID == "asset_123")
        #expect(overlay.title.raw == "04 晴天")
        #expect(overlay.title.canonical == nil)
        #expect(overlay.title.user == nil)
        #expect(overlay.resolvedTitle == "04 晴天")
        #expect(overlay.title.activeSource == .raw)

        #expect(overlay.artist.raw == "Jay Chou")
        #expect(overlay.resolvedArtist == "Jay Chou")

        #expect(overlay.album.raw == "叶惠美")
        #expect(overlay.resolvedAlbum == "叶惠美")

        #expect(!overlay.hasUserOverrides)
        #expect(!overlay.isEnriched)
    }

    @Test
    func canonicalEnrichmentOverrulesRawWithoutMutatingRaw() {
        var overlay = TrackMetadataOverlay(
            rawTitle: "track04_rough",
            rawArtist: "Jay",
            rawAlbum: "Album 2003"
        )

        #expect(overlay.resolvedTitle == "track04_rough")
        #expect(!overlay.isEnriched)

        // Enrich with authoritative MusicBrainz canonical data
        overlay.applyCanonicalMetadata(
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 4,
            discNumber: 1,
            year: 2003,
            genre: "Pop"
        )

        #expect(overlay.isEnriched)
        #expect(!overlay.hasUserOverrides)

        // Effective values are now canonical
        #expect(overlay.resolvedTitle == "晴天")
        #expect(overlay.resolvedArtist == "周杰伦")
        #expect(overlay.resolvedAlbum == "叶惠美")
        #expect(overlay.resolvedTrackNumber == 4)
        #expect(overlay.resolvedDiscNumber == 1)
        #expect(overlay.resolvedYear == 2003)
        #expect(overlay.resolvedGenre == "Pop")

        // Crucial safety guarantee: raw tags are completely intact
        #expect(overlay.title.raw == "track04_rough")
        #expect(overlay.artist.raw == "Jay")
        #expect(overlay.album.raw == "Album 2003")
        #expect(overlay.title.activeSource == .canonical)
    }

    @Test
    func userOverridePrecedesCanonicalAndRaw() {
        var overlay = TrackMetadataOverlay(
            rawTitle: "晴天 (Original Mix)",
            rawArtist: "周杰伦"
        )

        overlay.applyCanonicalMetadata(
            title: "晴天",
            artist: "周杰伦"
        )

        #expect(overlay.resolvedTitle == "晴天")
        #expect(overlay.title.activeSource == .canonical)

        // User makes custom edit
        overlay.title.setUserOverride("晴天 (Live at Taipei)")

        #expect(overlay.hasUserOverrides)
        #expect(overlay.title.isOverridden)
        #expect(overlay.resolvedTitle == "晴天 (Live at Taipei)")
        #expect(overlay.title.activeSource == .user)

        // Canonical and raw values remain preserved underneath
        #expect(overlay.title.canonical == "晴天")
        #expect(overlay.title.raw == "晴天 (Original Mix)")
    }

    @Test
    func resetOperationsRestoreStateNonDestructively() {
        var overlay = TrackMetadataOverlay(
            rawTitle: "track_raw",
            rawArtist: "artist_raw",
            rawAlbum: "album_raw"
        )

        overlay.applyCanonicalMetadata(
            title: "Track Canonical",
            artist: "Artist Canonical",
            album: "Album Canonical"
        )

        overlay.title.setUserOverride("Track User")
        overlay.artist.setUserOverride("Artist User")

        #expect(overlay.resolvedTitle == "Track User")
        #expect(overlay.resolvedArtist == "Artist User")

        // 1. Reset all to canonical
        overlay.resetAllToCanonical()

        #expect(!overlay.hasUserOverrides)
        #expect(overlay.resolvedTitle == "Track Canonical")
        #expect(overlay.resolvedArtist == "Artist Canonical")
        #expect(overlay.resolvedAlbum == "Album Canonical")
        #expect(overlay.title.raw == "track_raw")

        // 2. Reset all to raw
        overlay.resetAllToRaw()

        #expect(!overlay.isEnriched)
        #expect(!overlay.hasUserOverrides)
        #expect(overlay.resolvedTitle == "track_raw")
        #expect(overlay.resolvedArtist == "artist_raw")
        #expect(overlay.resolvedAlbum == "album_raw")
    }

    @Test
    func fieldLevelGranularFallbackAllowsMixedLayers() {
        var overlay = TrackMetadataOverlay(
            rawTitle: "track_raw",
            rawArtist: "artist_raw",
            rawAlbum: "album_raw"
        )

        overlay.applyCanonicalMetadata(
            title: "Track Canonical",
            artist: "Artist Canonical",
            album: "Album Canonical"
        )

        overlay.title.setUserOverride("Track User")

        // title: user override
        #expect(overlay.title.activeSource == .user)
        #expect(overlay.resolvedTitle == "Track User")

        // artist: canonical enrichment
        #expect(overlay.artist.activeSource == .canonical)
        #expect(overlay.resolvedArtist == "Artist Canonical")

        // album: reset single field to raw
        overlay.album.resetToRaw()
        #expect(overlay.album.activeSource == .raw)
        #expect(overlay.resolvedAlbum == "album_raw")

        // Clearing user override on title falls back specifically to canonical
        overlay.title.clearUserOverride()
        #expect(overlay.title.activeSource == .canonical)
        #expect(overlay.resolvedTitle == "Track Canonical")
    }

    @Test
    func overlayCodableRoundTripPreservesAllLayers() throws {
        var overlay = TrackMetadataOverlay(
            id: "track_001",
            assetID: "asset_001",
            rawTitle: "raw_title",
            rawArtist: "raw_artist"
        )
        overlay.applyCanonicalMetadata(title: "canonical_title", artist: "canonical_artist")
        overlay.title.setUserOverride("user_title")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(overlay)
        let decoded = try decoder.decode(TrackMetadataOverlay.self, from: data)

        #expect(decoded.id == overlay.id)
        #expect(decoded.assetID == overlay.assetID)
        #expect(decoded.title == overlay.title)
        #expect(decoded.artist == overlay.artist)
        #expect(decoded.resolvedTitle == "user_title")
        #expect(decoded.resolvedArtist == "canonical_artist")
        #expect(decoded.title.raw == "raw_title")
    }
}
