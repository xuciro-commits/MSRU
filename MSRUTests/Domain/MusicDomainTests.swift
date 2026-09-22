//
//  MusicDomainTests.swift
//  MSRUTests
//
//  Canonical domain model tests protecting core music invariants:
//  Work != Recording != ReleaseTrack != Asset, multi-asset ownership,
//  live/studio distinction, and composite artist credit semantics.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@Suite("Music Domain Core Invariants")
struct MusicDomainTests {

    @Test
    func oneRecordingCanOwnMultipleAssets() {
        // Arrange: A single canonical recording
        let recordingID = "rec_sunny_day_canonical"
        let recording = Fixtures.makeRecording(id: recordingID, title: "晴天")

        // Act: Two distinct assets (Hi-Res FLAC master & mobile AAC) reference this recording
        let hiResMaster = AudioAsset(
            id: "ast_flac_master",
            fileURL: URL(fileURLWithPath: "/storage/masters/sunny_24_96.flac"),
            fileSize: 48_000_000,
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            duration: 269.0,
            recordingID: recording.id
        )

        let mobileCopy = AudioAsset(
            id: "ast_aac_mobile",
            fileURL: URL(fileURLWithPath: "/storage/mobile/sunny_256.aac"),
            fileSize: 8_500_000,
            format: "AAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            duration: 269.0,
            recordingID: recording.id
        )

        // Assert: Both assets attach to the same recording without creating a second recording
        #expect(hiResMaster.recordingID == recording.id)
        #expect(mobileCopy.recordingID == recording.id)
        #expect(hiResMaster.id != mobileCopy.id)
        #expect(hiResMaster.isHiRes)
        #expect(!mobileCopy.isHiRes)
    }

    @Test
    func sameTitleDoesNotImplySameRecordingForStudioAndLive() {
        // Arrange: The abstract composition (Work)
        let work = Fixtures.makeWork(id: "wrk_sunny", title: "晴天")

        // Act: Studio version (2003) vs Live Concert capture (2004)
        let studioRecording = Recording(
            id: "rec_sunny_studio_2003",
            title: "晴天",
            artistCredit: ArtistCredit(headline: "周杰伦", participations: []),
            workID: work.id,
            duration: 269.0,
            isLive: false
        )

        let liveRecording = Recording(
            id: "rec_sunny_live_2004",
            title: "晴天 (2004 无与伦比演唱会 Live)",
            artistCredit: ArtistCredit(headline: "周杰伦", participations: []),
            workID: work.id,
            duration: 295.0,
            isLive: true
        )

        // Assert: They reference the same Work but MUST remain distinct Recordings
        #expect(studioRecording.workID == liveRecording.workID)
        #expect(studioRecording.id != liveRecording.id)
        #expect(!studioRecording.isLive)
        #expect(liveRecording.isLive)
        #expect(studioRecording.duration != liveRecording.duration)
    }

    @Test
    func artistCreditSeparatesHeadlineFromConstituentArtists() {
        // Arrange: Primary and featured artist entities
        let taylor = ArtistEntity(id: "art_taylor", canonicalName: "Taylor Swift")
        let post = ArtistEntity(id: "art_post", canonicalName: "Post Malone")

        // Act: Create structured collaboration credit
        let credit = ArtistCredit(primary: taylor, featured: [post])

        // Assert: Headline is formatted properly, while constituent artist entities remain independent
        #expect(credit.headline == "Taylor Swift feat. Post Malone")
        #expect(credit.primaryArtists.count == 1)
        #expect(credit.primaryArtists.first?.canonicalName == "Taylor Swift")
        #expect(credit.featuredArtists.count == 1)
        #expect(credit.featuredArtists.first?.canonicalName == "Post Malone")
        #expect(credit.primaryArtists.first?.id != credit.featuredArtists.first?.id)
    }

    @Test
    func releaseGroupUnifiesDifferentReleaseEditions() {
        // Arrange: Abstract album concept (ReleaseGroup)
        let releaseGroup = Fixtures.makeReleaseGroup(id: "rg_ye_hui_mei", title: "叶惠美")

        // Act: Taiwan CD original (2003) vs Remastered Vinyl (2020)
        let twCD = Fixtures.makeRelease(
            id: "rel_tw_cd_2003",
            releaseGroupID: releaseGroup.id,
            title: "叶惠美",
            date: "2003-07-31",
            country: "TW"
        )

        let vinyl2020 = Fixtures.makeRelease(
            id: "rel_vinyl_2020",
            releaseGroupID: releaseGroup.id,
            title: "叶惠美 (20周年经典黑胶版)",
            date: "2020-11-06",
            country: "TW"
        )

        // Assert: Both concrete releases belong to the same ReleaseGroup
        #expect(twCD.releaseGroupID == releaseGroup.id)
        #expect(vinyl2020.releaseGroupID == releaseGroup.id)
        #expect(twCD.id != vinyl2020.id)
        #expect(twCD.date != vinyl2020.date)
    }

    @Test
    func audioAssetLosslessAndHiResClassification() {
        // Arrange
        let flacHiRes = Fixtures.makeAudioAsset(format: "FLAC", bitDepth: "24-bit", sampleRate: 96000)
        let cdFlac = Fixtures.makeAudioAsset(format: "FLAC", bitDepth: "16-bit", sampleRate: 44100)
        let aacLossy = Fixtures.makeAudioAsset(format: "AAC", bitDepth: "16-bit", sampleRate: 44100)

        // Assert
        #expect(flacHiRes.isLossless)
        #expect(flacHiRes.isHiRes)

        #expect(cdFlac.isLossless)
        #expect(!cdFlac.isHiRes)

        #expect(!aacLossy.isLossless)
        #expect(!aacLossy.isHiRes)
    }
}
