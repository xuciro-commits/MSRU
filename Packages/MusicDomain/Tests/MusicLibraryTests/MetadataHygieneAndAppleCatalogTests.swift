//
//  MetadataHygieneAndAppleCatalogTests.swift
//  MSRU
//
//  Unit tests for MetadataSanitizer, LocalArtworkExtractor Chinese support,
//  and Apple Catalog track alignment.
//

import Foundation
import Testing
@testable import MusicLibrary
@testable import MusicDomain

@Suite("Metadata Hygiene & Apple Catalog Tests")
struct MetadataHygieneAndAppleCatalogTests {

    @Test("MetadataSanitizer strips track number prefixes correctly")
    func testTrackNumberPrefixStripping() {
        let (t1, no1, isAnom1) = MetadataSanitizer.cleanTrackTitle("01. 太阳雨")
        #expect(t1 == "太阳雨")
        #expect(no1 == 1)
        #expect(!isAnom1)

        let (t2, no2, isAnom2) = MetadataSanitizer.cleanTrackTitle("02-红豆")
        #expect(t2 == "红豆")
        #expect(no2 == 2)
        #expect(!isAnom2)

        let (t3, no3, isAnom3) = MetadataSanitizer.cleanTrackTitle("03 恰似你的温柔")
        #expect(t3 == "恰似你的温柔")
        #expect(no3 == 3)
        #expect(!isAnom3)
    }

    @Test("MetadataSanitizer detects placeholder titles as anomalous")
    func testPlaceholderAnomalyDetection() {
        let (t1, no1, isAnom1) = MetadataSanitizer.cleanTrackTitle("Track05")
        #expect(t1 == "Track05")
        #expect(no1 == 5)
        #expect(isAnom1)

        let (t2, no2, isAnom2) = MetadataSanitizer.cleanTrackTitle("AudioTrack 02")
        #expect(t2 == "AudioTrack 02")
        #expect(no2 == 2)
        #expect(isAnom2)

        let (t3, no3, isAnom3) = MetadataSanitizer.cleanTrackTitle("CD Track 12")
        #expect(t3 == "CD Track 12")
        #expect(no3 == 12)
        #expect(isAnom3)

        #expect(MetadataSanitizer.isAnomalousTitle("Track01"))
        #expect(MetadataSanitizer.isAnomalousTitle("track_04"))
        #expect(MetadataSanitizer.isAnomalousTitle("15"))
    }

    @Test("MetadataSanitizer strips artist prefixes and hyphenated names from title")
    func testArtistPrefixStripping() {
        let (t1, _, _) = MetadataSanitizer.cleanTrackTitle("李克勤 - 一生不变", artist: "李克勤")
        #expect(t1 == "一生不变")

        let (t2, _, _) = MetadataSanitizer.cleanTrackTitle("陈果-幻影", artist: "陈果")
        #expect(t2 == "幻影")

        let (t3, _, _) = MetadataSanitizer.cleanTrackTitle("张学友 - 吻别")
        #expect(t3 == "吻别")
    }

    @Test("MetadataSanitizer cleans format, edition, and rip tags from album")
    func testAlbumTitleCleaning() {
        #expect(MetadataSanitizer.cleanAlbumTitle("幻影 [16-44.1][qobuz]") == "幻影")
        #expect(MetadataSanitizer.cleanAlbumTitle("[2016] 陈果 - 幻影 [16-44.1][qobuz]", artist: "陈果") == "幻影")
        #expect(MetadataSanitizer.cleanAlbumTitle("民歌红 4 DTS6.1[WAV+CUE]1") == "民歌红 4")
        #expect(MetadataSanitizer.cleanAlbumTitle("流金三十年 [HQCDII]") == "流金三十年")
        #expect(MetadataSanitizer.cleanAlbumTitle("经典老歌【无损】") == "经典老歌")
        #expect(MetadataSanitizer.cleanAlbumTitle("民歌红 4", artist: "杨曼莉") == "民歌红 4")
    }

    @Test("MetadataSanitizer cleans web tags and brackets from artist name")
    func testArtistNameCleaning() {
        #expect(MetadataSanitizer.cleanArtistName("[51ape.com]郑源") == "郑源")
        #expect(MetadataSanitizer.cleanArtistName("刘文正.流金三十年][6N纯银镀膜CD]") == "刘文正")
        #expect(MetadataSanitizer.cleanArtistName("王菲") == "王菲")
    }

    @Test("AppleTrackMatch and AppleAlbumMatch initialization and ordering")
    func testAppleCatalogModels() {
        let album = AppleAlbumMatch(
            collectionId: 1558444795,
            title: "民歌红4",
            artist: "杨曼莉",
            releaseDate: "2010-01-01",
            trackCount: 12,
            genre: "Mandopop",
            artworkURL: URL(string: "https://example.com/cover.jpg")
        )
        #expect(album.collectionId == 1558444795)
        #expect(album.title == "民歌红4")

        let t1 = AppleTrackMatch(trackId: 101, collectionId: 1558444795, trackNumber: 5, title: "送别", artist: "杨曼莉", duration: 255.8)
        let t2 = AppleTrackMatch(trackId: 102, collectionId: 1558444795, trackNumber: 1, title: "沉浮", artist: "杨曼莉", duration: 282.8)

        let sorted = [t1, t2].sorted { $0.trackNumber < $1.trackNumber }
        #expect(sorted.first?.title == "沉浮")
        #expect(sorted.last?.title == "送别")
    }

    @Test("Verify real FLAC Vorbis album, Chinese cover art discovery, and Apple Catalog alignment")
    func testRealWorldVerification() async throws {
        let flacPath = "/Volumes/团队文件-home.zhuhai/03 音乐资源/音乐/1.歌曲/女歌手/陈果/[2016] 陈果 - 幻影 [16-44.1][qobuz]/03. 雨丝情愁.flac"
        let wavFolder = "/Volumes/团队文件-home.zhuhai/03 音乐资源/音乐/1.歌曲/女歌手/杨曼莉/杨曼莉 民歌红 4 DTS6.1[WAV+CUE]1"

        // 1. Verify FLAC readTrack now extracts Album = "幻影" and embedded artwork!
        if FileManager.default.fileExists(atPath: flacPath) {
            let track = try await SQLiteLocalLibraryRepository.readTrack(from: URL(fileURLWithPath: flacPath))
            #expect(track.title == "雨丝情愁")
            #expect(track.artist == "陈果")
            #expect(track.album == "幻影")
            #expect(track.artworkData != nil && !track.artworkData!.isEmpty)
        }

        // 2. Verify Chinese artwork "封面.jpg" is now discovered in the WAV folder!
        if FileManager.default.fileExists(atPath: wavFolder) {
            let art = LocalArtworkExtractor.extractFromDirectory(folderURL: URL(fileURLWithPath: wavFolder))
            #expect(art != nil && art!.count == 226309) // exact bytes of 封面.jpg!
        }

        // 3. Verify AppleCatalogService aligns Track05 to "送别"
        let mockLocalTrack05 = LocalTrack(
            fileURL: URL(fileURLWithPath: "\(wavFolder)/05. Track05.wav"),
            title: "Track05",
            artist: "杨曼莉",
            album: nil,
            duration: 258.5,
            trackNumber: 5
        )
        if let (aligned, canonicalAlbum, _) = await AppleCatalogService.shared.alignAlbum(
            artistHint: "杨曼莉",
            albumHint: "民歌红 4",
            localTracks: [mockLocalTrack05]
        ) {
            #expect(canonicalAlbum == "民歌红4")
            #expect(aligned.first?.title == "送别")
            #expect(aligned.first?.trackNumber == 5)
        }
    }
}
