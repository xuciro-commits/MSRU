//
//  TrackVersionsTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct TrackVersionsTests {

    @Test
    func trackVersionsElectsHighestQualityAssetAsPrimary() {
        let flacHiRes = AudioAsset(
            id: "asset_hires_flac",
            fileURL: URL(fileURLWithPath: "/music/track_24_96.flac"),
            fileSize: 95_000_000,
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            recordingID: "rec_sunny_day"
        )
        let flacCD = AudioAsset(
            id: "asset_cd_flac",
            fileURL: URL(fileURLWithPath: "/music/track_16_44.flac"),
            fileSize: 32_000_000,
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            recordingID: "rec_sunny_day"
        )
        let mp3 = AudioAsset(
            id: "asset_mp3",
            fileURL: URL(fileURLWithPath: "/music/track_320k.mp3"),
            fileSize: 7_500_000,
            format: "MP3",
            sampleRate: 44100,
            bitrateKbps: 320,
            recordingID: "rec_sunny_day"
        )

        var versions = TrackVersions(recordingID: "rec_sunny_day", assets: [mp3, flacCD, flacHiRes])

        #expect(versions.versionCount == 3)
        #expect(versions.hasMultipleVersions)
        #expect(versions.primaryAsset?.id == "asset_hires_flac")
        #expect(!versions.isUserPinned)
        #expect(versions.alternativeAssets.count == 2)
        #expect(versions.primaryBadgeText.contains("24-bit"))
        #expect(versions.primaryBadgeText.contains("96 kHz"))
        #expect(versions.primaryBadgeText.contains("Hi-Res"))
    }

    @Test
    func manualPinningOverridesQualityRankingUntilCleared() {
        let flacHiRes = AudioAsset(
            id: "asset_hires_flac",
            fileURL: URL(fileURLWithPath: "/music/track_24_96.flac"),
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            recordingID: "rec_1"
        )
        let mp3 = AudioAsset(
            id: "asset_mp3",
            fileURL: URL(fileURLWithPath: "/music/track_320k.mp3"),
            format: "MP3",
            sampleRate: 44100,
            bitrateKbps: 320,
            recordingID: "rec_1"
        )

        var versions = TrackVersions(recordingID: "rec_1", assets: [flacHiRes, mp3])
        #expect(versions.primaryAsset?.id == "asset_hires_flac")

        // User manually pins MP3
        versions.setManualPrimary(assetID: "asset_mp3")
        #expect(versions.isUserPinned)
        #expect(versions.primaryAsset?.id == "asset_mp3")
        #expect(versions.alternativeAssets.map(\.id) == ["asset_hires_flac"])

        // User clears manual pin -> reverts to Hi-Res FLAC
        versions.clearManualPrimary()
        #expect(!versions.isUserPinned)
        #expect(versions.primaryAsset?.id == "asset_hires_flac")
    }

    @Test
    func addingAndRemovingVersionsMaintainsConsistency() {
        let cd = AudioAsset(
            id: "asset_cd",
            fileURL: URL(fileURLWithPath: "/music/cd.flac"),
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            recordingID: "rec_1"
        )
        var versions = TrackVersions(primaryAsset: cd)
        #expect(versions.versionCount == 1)
        #expect(!versions.hasMultipleVersions)

        // Add 24/192 ultra hi-res
        let ultraHiRes = AudioAsset(
            id: "asset_ultra",
            fileURL: URL(fileURLWithPath: "/music/ultra.flac"),
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 192000,
            recordingID: "rec_1"
        )
        versions.addVersion(ultraHiRes)
        #expect(versions.versionCount == 2)
        #expect(versions.primaryAsset?.id == "asset_ultra")

        // Remove primary -> falls back to CD
        let removed = versions.removeVersion(assetID: "asset_ultra")
        #expect(removed?.id == "asset_ultra")
        #expect(versions.versionCount == 1)
        #expect(versions.primaryAsset?.id == "asset_cd")
    }

    @Test
    func trackVersionsSupportsCodableRoundTrip() throws {
        let flac = AudioAsset(
            id: "asset_1",
            fileURL: URL(fileURLWithPath: "/music/1.flac"),
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            recordingID: "rec_1"
        )
        let mp3 = AudioAsset(
            id: "asset_2",
            fileURL: URL(fileURLWithPath: "/music/2.mp3"),
            format: "MP3",
            sampleRate: 44100,
            bitrateKbps: 320,
            recordingID: "rec_1"
        )

        var versions = TrackVersions(recordingID: "rec_1", assets: [flac, mp3])
        versions.setManualPrimary(assetID: "asset_2")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(versions)
        let decoded = try decoder.decode(TrackVersions.self, from: data)

        #expect(decoded.recordingID == versions.recordingID)
        #expect(decoded.versionCount == 2)
        #expect(decoded.userDesignatedPrimaryID == "asset_2")
        #expect(decoded.primaryAsset?.id == "asset_2")
    }
}
