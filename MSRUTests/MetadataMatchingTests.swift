//
//  MetadataMatchingTests.swift
//  MSRUTests
//
//  Unit tests covering Pinyin transliteration matching, duet consolidation,
//  and multi-provider artwork resolution.
//

import XCTest
@testable import MSRU
import AppFoundation

final class MetadataMatchingTests: XCTestCase {

    func testPinyinLatinTransliteration() {
        let pairs: [(String, String)] = [
            ("為你好", "wei ni hao"),
            ("反叛", "fan pan"),
            ("情意結", "qing yi jie"),
            ("嫻情", "xian qing"),
            ("秋色", "qiu se"),
            ("故事的感覺", "gu shi de gan jue"),
            ("問題女人", "wen ti nu ren"),
            ("歸來吧", "gui lai ba"),
            ("今天的愛人是誰", "jin tian de ai ren shi shui"),
            ("永遠是你的朋友", "yong yuan shi ni de peng you"),
            ("By Heart - SACD", "by heart"),
            ("Get Up & Dance", "get up dance")
        ]

        for (input, expected) in pairs {
            let actual = MusicBrainzCatalogClient.toPinyinLatin(input)
            XCTAssertEqual(actual, expected, "Failed transliteration for '\(input)'")
        }
    }

    func testTightHyphenFileNameParsing() {
        let parsed = FileNameHeuristicParser.parse(fileName: "李克勤-护花使者.ape")
        XCTAssertEqual(parsed.artist, "李克勤")
        XCTAssertEqual(parsed.title, "护花使者")

        let parsedStandard = FileNameHeuristicParser.parse(fileName: "Adele - Hello.flac")
        XCTAssertEqual(parsedStandard.artist, "Adele")
        XCTAssertEqual(parsedStandard.title, "Hello")
    }

    @MainActor
    func testDuetAlbumConsolidation() {
        let track1 = LocalTrack(
            fileURL: URL(fileURLWithPath: "/music/track1.flac"),
            title: "夜了点",
            artist: "Priscilla Chan",
            album: "你身邊永是我",
            duration: 210,
            trackNumber: 1
        )
        let track2 = LocalTrack(
            fileURL: URL(fileURLWithPath: "/music/track2.flac"),
            title: "好想永远这样",
            artist: "Priscilla Chan, Leon Lai",
            album: "你身邊永是我",
            duration: 230,
            trackNumber: 2
        )
        let track3 = LocalTrack(
            fileURL: URL(fileURLWithPath: "/music/track3.flac"),
            title: "故梦",
            artist: "Priscilla Chan, Vivian Lai",
            album: "你身邊永是我",
            duration: 220,
            trackNumber: 3
        )

        let albums = LibraryPresentationAggregator.buildAlbums(from: [track1, track2, track3])
        XCTAssertEqual(albums.count, 1, "Duet tracks should not fragment the album into multiple album cards")
        XCTAssertEqual(albums.first?.title, "你身邊永是我")
        XCTAssertEqual(albums.first?.artist, "Priscilla Chan")
        XCTAssertEqual(albums.first?.trackCount, 3)

        let artists = LibraryPresentationAggregator.buildArtists(from: [track1, track2, track3])
        XCTAssertEqual(artists.count, 1, "Duet tracks should be attributed to primary artist")
        XCTAssertEqual(artists.first?.name, "Priscilla Chan")
    }

    func testIsValidImageData() {
        // Valid JPEG header
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0), count: 30))
        XCTAssertTrue(LocalArtworkExtractor.isValidImageData(jpegHeader))

        // Valid PNG header
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + Array(repeating: UInt8(0), count: 25))
        XCTAssertTrue(LocalArtworkExtractor.isValidImageData(pngHeader))

        // Invalid junk bytes
        let junk = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        XCTAssertFalse(LocalArtworkExtractor.isValidImageData(junk))
    }
}
