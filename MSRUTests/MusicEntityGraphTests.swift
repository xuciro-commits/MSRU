//
//  MusicEntityGraphTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 1.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct MusicEntityGraphTests {

    @Test
    func artistEntityWithAliasesResolvesCorrectDisplayNameByLocale() {
        let aliases: [EntityAlias] = [
            EntityAlias(name: "Jay Chou", localeIdentifier: "en", isPrimary: false),
            EntityAlias(name: "周杰倫", localeIdentifier: "zh-Hant", isPrimary: false),
            EntityAlias(name: "周杰伦", localeIdentifier: "zh-Hans", isPrimary: true)
        ]

        let artist = ArtistEntity(
            id: "artist_jay_chou",
            canonicalName: "周杰伦",
            aliases: aliases,
            disambiguation: "Taiwanese singer-songwriter",
            country: "TW"
        )

        #expect(artist.id == "artist_jay_chou")
        #expect(artist.disambiguation == "Taiwanese singer-songwriter")

        // Preferred English
        let enName = artist.displayName(preferredLocales: [Locale(identifier: "en")])
        #expect(enName == "Jay Chou")

        // Preferred Traditional Chinese
        let hantName = artist.displayName(preferredLocales: [Locale(identifier: "zh-Hant")])
        #expect(hantName == "周杰倫")

        // Preferred Simplified Chinese
        let hansName = artist.displayName(preferredLocales: [Locale(identifier: "zh-Hans")])
        #expect(hansName == "周杰伦")
    }

    @Test
    func artistCreditSeparatesDisplayStringFromParticipations() {
        let jay = ArtistEntity(id: "artist_jay", canonicalName: "Jay Chou")
        let gary = ArtistEntity(id: "artist_gary", canonicalName: "Gary Yang")

        let credit = ArtistCredit(primary: jay, featured: [gary])

        #expect(credit.headline == "Jay Chou feat. Gary Yang")
        #expect(credit.participations.count == 2)
        #expect(credit.primaryArtists.map(\.id) == ["artist_jay"])
        #expect(credit.featuredArtists.map(\.id) == ["artist_gary"])
    }

    @Test
    func fullEntityGraphConstructsValidHierarchy() {
        // 1. Work (Abstract composition)
        let jay = ArtistEntity(id: "artist_jay", canonicalName: "周杰伦")
        let work = Work(
            id: "work_sunny_day",
            title: "晴天",
            workType: .song,
            composers: [jay],
            lyricists: [jay],
            iswc: "T-043.435.700-1"
        )
        #expect(work.id == "work_sunny_day")
        #expect(work.composers.map(\.canonicalName) == ["周杰伦"])

        // 2. Recording (Concrete recording event)
        let jayCredit = ArtistCredit(single: jay)
        let recording = Recording(
            id: "rec_sunny_day_2003",
            title: "晴天",
            artistCredit: jayCredit,
            workID: work.id,
            duration: 269.0,
            isrc: "TWA470305004",
            isLive: false
        )
        #expect(recording.workID == "work_sunny_day")
        #expect(!recording.isLive)

        // 3. ReleaseGroup (Album concept)
        let releaseGroup = ReleaseGroup(
            id: "rg_ye_hui_mei",
            title: "叶惠美",
            artistCredit: jayCredit,
            primaryType: .album,
            firstReleaseDate: "2003-07-31"
        )
        #expect(releaseGroup.primaryType == .album)

        // 4. Release (Specific edition: 2003 Taiwan CD)
        let musicTrack = MusicTrack(
            id: "track_04",
            recordingID: recording.id,
            position: 4,
            number: "4",
            title: "晴天",
            duration: 269.0
        )
        let cdMedium = Medium(
            position: 1,
            format: "CD",
            title: "Disc 1",
            tracks: [musicTrack]
        )
        let release = Release(
            id: "rel_taiwan_cd",
            releaseGroupID: releaseGroup.id,
            title: "叶惠美",
            artistCredit: jayCredit,
            date: "2003-07-31",
            country: "TW",
            barcode: "0724359265225",
            media: [cdMedium]
        )
        #expect(release.media.count == 1)
        #expect(release.media[0].tracks.count == 1)
        #expect(release.media[0].tracks[0].recordingID == "rec_sunny_day_2003")

        // 5. AudioAsset (Physical file on disk)
        let audioAsset = AudioAsset(
            id: "asset_flac_24_96",
            fileURL: URL(fileURLWithPath: "/Music/Jay/YeHuiMei/04_SunnyDay.flac"),
            fileSize: 52_428_800,
            sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            bitrateKbps: 1550,
            duration: 269.0,
            acoustID: "acoust_sunny_day_hash",
            recordingID: recording.id
        )
        #expect(audioAsset.isLossless)
        #expect(audioAsset.isHiRes)
        #expect(audioAsset.recordingID == recording.id)
    }

    @Test
    func entitiesAreCodable() throws {
        let work = Work(id: "work_1", title: "In the End", workType: .song)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(work)
        let decoded = try decoder.decode(Work.self, from: data)
        #expect(decoded == work)

        let lp = ArtistEntity(id: "art_lp", canonicalName: "Linkin Park")
        let lpCredit = ArtistCredit(single: lp)
        let release = Release(id: "rel_1", releaseGroupID: "rg_1", title: "Hybrid Theory", artistCredit: lpCredit)
        let releaseData = try encoder.encode(release)
        let decodedRelease = try decoder.decode(Release.self, from: releaseData)
        #expect(decodedRelease == release)
    }
}
