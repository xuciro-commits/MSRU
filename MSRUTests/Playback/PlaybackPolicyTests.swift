//
//  PlaybackPolicyTests.swift
//  MSRUTests
//
//  Tests for PlaybackPolicy and candidate selection across local and remote sources.
//

import Foundation
import Testing
import AppFoundation
import MusicDomain
@testable import MSRU

@MainActor
@Suite("Playback Policy & Multi-Source Selection")
struct PlaybackPolicyTests {

    @Test("StandardPlaybackPolicy respects explicit preferredSourceID override")
    func explicitSourceOverride() {
        let policy = StandardPlaybackPolicy()
        let pref = PlaybackPreference(preferredSourceID: "src_subsonic_1", qualityMode: .preferLocal)

        let localCandidate = PlaybackAssetCandidate(
            assetID: AssetID("ast_local_1"),
            sourceID: SourceID("local"),
            sourceType: .localFolder,
            format: "FLAC",
            bitrateKbps: 900,
            isLossless: true,
            isLocal: true
        )

        let remoteCandidate = PlaybackAssetCandidate(
            assetID: AssetID("ast_remote_1"),
            sourceID: SourceID("src_subsonic_1"),
            sourceType: .networkFolder,
            format: "MP3",
            bitrateKbps: 320,
            isLossless: false,
            isLocal: false
        )

        let selected = policy.selectCandidate(from: [localCandidate, remoteCandidate], preference: pref)
        #expect(selected?.assetID.rawValue == "ast_remote_1")
    }

    @Test("StandardPlaybackPolicy prefers local in .preferLocal mode")
    func preferLocalMode() {
        let policy = StandardPlaybackPolicy()
        let pref = PlaybackPreference(preferredSourceID: nil, qualityMode: .preferLocal)

        let localCandidate = PlaybackAssetCandidate(
            assetID: AssetID("ast_local_1"),
            sourceID: SourceID("local"),
            sourceType: .localFolder,
            format: "MP3",
            bitrateKbps: 320,
            isLossless: false,
            isLocal: true
        )

        let remoteCandidate = PlaybackAssetCandidate(
            assetID: AssetID("ast_remote_1"),
            sourceID: SourceID("src_subsonic_1"),
            sourceType: .networkFolder,
            format: "FLAC",
            bitrateKbps: 1000,
            isLossless: true,
            isLocal: false
        )

        let selected = policy.selectCandidate(from: [remoteCandidate, localCandidate], preference: pref)
        #expect(selected?.assetID.rawValue == "ast_local_1")
        #expect(selected?.isLocal == true)
    }

    @Test("StandardPlaybackPolicy chooses lossless in .highestQuality mode")
    func highestQualityModeChoosesLossless() {
        let policy = StandardPlaybackPolicy()
        let pref = PlaybackPreference(preferredSourceID: nil, qualityMode: .highestQuality)

        let localLossy = PlaybackAssetCandidate(
            assetID: AssetID("ast_local_mp3"),
            sourceID: SourceID("local"),
            sourceType: .localFolder,
            format: "MP3",
            bitrateKbps: 192,
            isLossless: false,
            isLocal: true
        )

        let remoteLossless = PlaybackAssetCandidate(
            assetID: AssetID("ast_remote_flac"),
            sourceID: SourceID("src_subsonic_1"),
            sourceType: .networkFolder,
            format: "FLAC",
            bitrateKbps: 1000,
            sampleRate: 96000,
            isLossless: true,
            isLocal: false
        )

        let selected = policy.selectCandidate(from: [localLossy, remoteLossless], preference: pref)
        #expect(selected?.assetID.rawValue == "ast_remote_flac")
    }

    @Test("PlaybackItem handles Subsonic payload and TrackRowSummary initializers correctly")
    func playbackItemSubsonicInitialization() {
        let item = PlaybackItem(
            subsonic: "sub_item_999",
            title: "Remote Song",
            artist: "Remote Artist",
            album: "NAS Album",
            duration: 240,
            artworkReference: "art_ref_999"
        )

        #expect(item.id == "subsonic:sub_item_999")
        #expect(item.source == .subsonic)
        #expect(item.title == "Remote Song")
        #expect(item.subtitle == "Remote Artist")
        #expect(item.providerLabel == "SUBSONIC")
        #expect(item.duration == 240)

        let req = item.playbackRequest
        #expect(req.itemID == "sub_item_999")
        #expect(req.source == .subsonic)
        #expect(req.providerHint == .subsonic)
    }
}
