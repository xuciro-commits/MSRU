//
//  DuplicateClassifierTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct DuplicateClassifierTests {

    @Test
    func caseA_FileDuplicate_DetectedByMatchingSHA256() {
        let asset1 = AudioAsset(
            id: "asset_1",
            fileURL: URL(fileURLWithPath: "/music/folderA/song.mp3"),
            fileSize: 8_192_000,
            sha256: "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            format: "MP3",
            bitrateKbps: 320,
            duration: 240.0
        )
        let asset2 = AudioAsset(
            id: "asset_2",
            fileURL: URL(fileURLWithPath: "/music/folderB/duplicate.mp3"),
            fileSize: 8_192_000,
            sha256: "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            format: "MP3",
            bitrateKbps: 320,
            duration: 240.0
        )

        let result = DuplicateClassifier.classify(assetA: asset1, assetB: asset2)

        #expect(result.category == .fileDuplicate)
        #expect(result.category.isSafeToMerge)
        #expect(result.actionStrategy == .safeDeduplicateFile)
        #expect(result.preferredAssetID == "asset_1")
    }

    @Test
    func caseB_DifferentEncoding_DetectedForSameRecordingDifferentCodec() {
        let assetFlac = AudioAsset(
            id: "asset_flac",
            fileURL: URL(fileURLWithPath: "/music/master.flac"),
            fileSize: 45_000_000,
            sha256: "hash_flac",
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            duration: 215.0,
            acoustID: "acoust_common_id",
            recordingID: "rec_common"
        )
        let assetMp3 = AudioAsset(
            id: "asset_mp3",
            fileURL: URL(fileURLWithPath: "/music/portable.mp3"),
            fileSize: 6_000_000,
            sha256: "hash_mp3",
            format: "MP3",
            bitDepth: "16-bit",
            sampleRate: 44100,
            bitrateKbps: 320,
            duration: 215.0,
            acoustID: "acoust_common_id",
            recordingID: "rec_common"
        )

        let result = DuplicateClassifier.classify(assetA: assetFlac, assetB: assetMp3)

        #expect(result.category == .differentEncoding)
        #expect(!result.category.isSafeToMerge)
        #expect(result.category.isSameRecording)
        #expect(result.actionStrategy == .coexistEncodings)
        // Lossless FLAC should be preferred over MP3
        #expect(result.preferredAssetID == "asset_flac")
    }

    @Test
    func caseC_QualityDifference_DetectedWhenSamplingOrBitDepthDiffers() {
        let hiRes = AudioAsset(
            id: "asset_hires",
            fileURL: URL(fileURLWithPath: "/music/hires.flac"),
            fileSize: 120_000_000,
            sha256: "hash_hires",
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            bitrateKbps: 2200,
            duration: 300.0,
            acoustID: "acoust_rec_1",
            recordingID: "rec_1"
        )
        let standardCD = AudioAsset(
            id: "asset_cd",
            fileURL: URL(fileURLWithPath: "/music/cd.flac"),
            fileSize: 35_000_000,
            sha256: "hash_cd",
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            bitrateKbps: 900,
            duration: 300.0,
            acoustID: "acoust_rec_1",
            recordingID: "rec_1"
        )

        let result = DuplicateClassifier.classify(assetA: hiRes, assetB: standardCD)

        #expect(result.category == .qualityDifference)
        #expect(result.category.isSameRecording)
        #expect(result.actionStrategy == .groupByQualitySelectPrimary)
        #expect(result.preferredAssetID == "asset_hires")
    }

    @Test
    func caseD_DifferentMaster_DetectedForSameWorkDifferentStudioReleases() {
        let work = Work(id: "work_hotel_california", title: "Hotel California", workType: .song)

        let originalMasterAsset = AudioAsset(
            id: "asset_1976",
            fileURL: URL(fileURLWithPath: "/music/1976_original.flac"),
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            duration: 390.0,
            recordingID: "rec_1976"
        )
        let remasterAsset = AudioAsset(
            id: "asset_2020",
            fileURL: URL(fileURLWithPath: "/music/2020_remaster.flac"),
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            duration: 391.0,
            recordingID: "rec_2020"
        )

        let rec1976 = Recording(
            id: "rec_1976",
            title: "Hotel California",
            artistCredit: ArtistCredit(headline: "Eagles", participations: []),
            workID: work.id,
            duration: 390.0,
            isLive: false
        )
        let rec2020 = Recording(
            id: "rec_2020",
            title: "Hotel California (2020 Remaster)",
            artistCredit: ArtistCredit(headline: "Eagles", participations: []),
            workID: work.id,
            duration: 391.0,
            isLive: false
        )

        let result = DuplicateClassifier.classify(
            assetA: originalMasterAsset,
            recordingA: rec1976,
            workA: work,
            assetB: remasterAsset,
            recordingB: rec2020,
            workB: work
        )

        #expect(result.category == .differentMaster)
        #expect(!result.category.isSameRecording)
        #expect(result.category.isSameWork)
        #expect(result.actionStrategy == .keepSeparateReleases)
    }

    @Test
    func caseE_DifferentPerformance_LiveVsStudioIsStrictlyNotDuplicate() {
        let work = Work(id: "work_hotel_california", title: "Hotel California", workType: .song)

        let studioAsset = AudioAsset(
            id: "asset_studio",
            fileURL: URL(fileURLWithPath: "/music/studio.flac"),
            format: "FLAC",
            duration: 390.0,
            recordingID: "rec_studio"
        )
        let liveAsset = AudioAsset(
            id: "asset_live_1994",
            fileURL: URL(fileURLWithPath: "/music/live1994.flac"),
            format: "FLAC",
            duration: 432.0,
            recordingID: "rec_live_1994"
        )

        let recStudio = Recording(
            id: "rec_studio",
            title: "Hotel California",
            artistCredit: ArtistCredit(headline: "Eagles", participations: []),
            workID: work.id,
            duration: 390.0,
            isLive: false
        )
        let recLive = Recording(
            id: "rec_live_1994",
            title: "Hotel California (Hell Freezes Over Live)",
            artistCredit: ArtistCredit(headline: "Eagles", participations: []),
            workID: work.id,
            duration: 432.0,
            isLive: true
        )

        let result = DuplicateClassifier.classify(
            assetA: studioAsset,
            recordingA: recStudio,
            workA: work,
            assetB: liveAsset,
            recordingB: recLive,
            workB: work
        )

        #expect(result.category == .differentPerformance)
        #expect(!result.category.isSameRecording)
        #expect(result.category.isSameWork)
        #expect(result.actionStrategy == .treatAsDistinctRecordings)
    }

    @Test
    func unrelatedTracksYieldNone() {
        let asset1 = AudioAsset(
            id: "asset_song1",
            fileURL: URL(fileURLWithPath: "/music/song1.flac"),
            format: "FLAC",
            duration: 200.0,
            recordingID: "rec_song1"
        )
        let asset2 = AudioAsset(
            id: "asset_song2",
            fileURL: URL(fileURLWithPath: "/music/song2.flac"),
            format: "FLAC",
            duration: 320.0,
            recordingID: "rec_song2"
        )

        let result = DuplicateClassifier.classify(assetA: asset1, assetB: asset2)
        #expect(result.category == .none)
        #expect(result.actionStrategy == .none)
    }
}
