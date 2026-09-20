//
//  AudioTagWriterTests.swift
//  MSRUTests
//
//  Created for Acoustic Metadata Pipeline Architecture Phase 4.
//

import Foundation
import Testing
@testable import MSRU

@MainActor
struct AudioTagWriterTests {

    @Test
    func writeFLACTagsAndEmbeddedArtwork() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("flac_tag_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let flacURL = tempDir.appendingPathComponent("test.flac")

        // Build a synthetic minimal FLAC container
        var mockFLAC = Data()
        mockFLAC.append("fLaC".data(using: .utf8)!)
        // STREAMINFO block: header (4 bytes: isLast=true, type=0, len=34)
        mockFLAC.append(contentsOf: [0x80, 0x00, 0x00, 0x22])
        mockFLAC.append(Data(repeating: 0x00, count: 34)) // 34 bytes streaminfo
        // Fake audio payload
        mockFLAC.append(Data(repeating: 0xAB, count: 512))
        try mockFLAC.write(to: flacURL)

        let mockCover = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46] + Array(repeating: UInt8(42), count: 64))

        let tags = AudioStandardTags(
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            albumArtist: "周杰伦",
            trackNumber: 3,
            totalTracks: 11,
            discNumber: 1,
            totalDiscs: 1,
            year: 2003,
            genre: "Pop",
            recordingMBID: "rec_sunny_day_123",
            releaseMBID: "rel_ye_hui_mei_456",
            artistMBID: "art_jay_chou_789",
            artworkData: mockCover
        )

        let writer = AudioTagWriter()
        let resultURL = try await writer.writeTags(to: flacURL, tags: tags)

        #expect(resultURL == flacURL)
        let writtenData = try Data(contentsOf: flacURL)

        // Verify magic bytes
        #expect(writtenData.count > mockFLAC.count)
        #expect(writtenData[0] == 0x66 && writtenData[1] == 0x4C && writtenData[2] == 0x61 && writtenData[3] == 0x43) // "fLaC"

        let contentString = String(decoding: writtenData, as: UTF8.self)
        #expect(contentString.contains("TITLE=晴天"))
        #expect(contentString.contains("ARTIST=周杰伦"))
        #expect(contentString.contains("ALBUM=叶惠美"))
        #expect(contentString.contains("TRACKNUMBER=3"))
        #expect(contentString.contains("MUSICBRAINZ_TRACKID=rec_sunny_day_123"))
        #expect(contentString.contains("MUSICBRAINZ_ALBUMID=rel_ye_hui_mei_456"))
    }

    @Test
    func writeMP3ID3v2TagsAndEmbeddedArtwork() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("mp3_tag_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mp3URL = tempDir.appendingPathComponent("test.mp3")

        // Build a synthetic minimal MP3: MPEG sync header 0xFF 0xFB + audio frame data
        var mockMP3 = Data([0xFF, 0xFB, 0x90, 0x64])
        mockMP3.append(Data(repeating: 0x55, count: 512))
        try mockMP3.write(to: mp3URL)

        let mockCover = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])

        let tags = AudioStandardTags(
            title: "以父之名",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 1,
            totalTracks: 11,
            year: 2003,
            recordingMBID: "rec_father_mbid",
            releaseMBID: "rel_ye_hui_mei_mbid",
            artworkData: mockCover
        )

        let writer = AudioTagWriter()
        let resultURL = try await writer.writeTags(to: mp3URL, tags: tags)

        #expect(resultURL == mp3URL)
        let writtenData = try Data(contentsOf: mp3URL)

        // Verify ID3v2.4 header: "ID3"
        #expect(writtenData.count > 10)
        #expect(writtenData[0] == 0x49 && writtenData[1] == 0x44 && writtenData[2] == 0x33) // "ID3"
        #expect(writtenData[3] == 0x04) // ID3v2.4

        let contentString = String(decoding: writtenData, as: UTF8.self)
        #expect(contentString.contains("以父之名"))
        #expect(contentString.contains("周杰伦"))
        #expect(contentString.contains("叶惠美"))
        #expect(contentString.contains("rec_father_mbid"))
    }

    @Test
    func companionArtworkFileExporterExportsCoverJpg() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("cover_export_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mockImage = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46] + Array(repeating: UInt8(1), count: 32))

        let exportedURL = ArtworkFileExporter.exportCover(artworkData: mockImage, to: tempDir)
        #expect(exportedURL != nil)
        #expect(exportedURL?.lastPathComponent == "cover.jpg")

        let diskData = try Data(contentsOf: exportedURL!)
        #expect(diskData == mockImage)
    }
}
