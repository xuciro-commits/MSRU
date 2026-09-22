//
//  AudioMetadataTagReaderTests.swift
//  MSRUTests
//
//  Created for Audio Metadata Tag Extraction and Resolution.
//

import Testing
import Foundation
@testable import MSRU

struct AudioMetadataTagReaderTests {

    @Test("DSFHeaderReader parses real DSF ID3 tags and APIC embedded artwork")
    func testRealDSFMetadataParsing() throws {
        let snowflakeURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语女/陈慧娴/陈慧娴 - Snowflake.dsf")
        guard FileManager.default.fileExists(atPath: snowflakeURL.path) else {
            print("Skipping testRealDSFMetadataParsing: external volume not mounted")
            return
        }

        guard let meta = DSFHeaderReader.readMetadata(from: snowflakeURL) else {
            Issue.record("Failed to read DSF header from Snowflake.dsf")
            return
        }

        #expect(meta.title == "Snowflake")
        #expect(meta.artist == "Priscilla Chan")
        #expect(meta.album == "By Heart - SACD")
        #expect(meta.trackNumber == 5)
        #expect(meta.year == 2014)
        #expect(meta.duration > 250 && meta.duration < 252)

        // Test real DSF with APIC embedded artwork
        let moonURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语女/陈慧娴/陈慧娴 - 月亮.dsf")
        if FileManager.default.fileExists(atPath: moonURL.path),
           let moonMeta = DSFHeaderReader.readMetadata(from: moonURL) {
            #expect(moonMeta.album == "归来吧SACD")
            #expect(moonMeta.artworkData != nil)
            #expect((moonMeta.artworkData?.count ?? 0) > 100_000)
        }
    }

    @Test("LocalLibraryRepository extracts real FLAC Vorbis comments and embedded picture")
    func testRealFLACVorbisCommentsAndArtwork() async throws {
        let jjURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语男/林俊杰精选集24bit/林俊杰 五月天 - 11.黑暗骑士.flac")
        guard FileManager.default.fileExists(atPath: jjURL.path) else {
            print("Skipping testRealFLACVorbisCommentsAndArtwork: external volume not mounted")
            return
        }

        let track = try await FileLocalLibraryRepository.readTrack(from: jjURL)

        #expect(track.album == "因你而在")
        #expect(track.title == "黑暗骑士")
        #expect(track.artworkData != nil)
        #expect((track.artworkData?.count ?? 0) > 10_000)
    }

    @Test("LocalLibraryRepository extracts FLAC Vorbis album instead of falling back to artist directory")
    func testFLACAlbumDisambiguation() async throws {
        let lkqURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语男/李克勤/李克勤-一生不变.flac")
        guard FileManager.default.fileExists(atPath: lkqURL.path) else {
            print("Skipping testFLACAlbumDisambiguation: external volume not mounted")
            return
        }

        let track = try await FileLocalLibraryRepository.readTrack(from: lkqURL)

        #expect(track.album == "宝丽金黄金时代精品典藏 VOL1 CD1")
        #expect(track.artist == "李克勤")
    }
}
