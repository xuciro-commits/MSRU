//
//  FileNameHeuristicParserTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import Testing
@testable import MSRU

@MainActor
struct FileNameHeuristicParserTests {

    @Test
    func parseLeadingTrackAndTitle() {
        let candidate1 = FileNameHeuristicParser.parse(fileName: "04 晴天.mp3")
        #expect(candidate1.trackNumber == 4)
        #expect(candidate1.title == "晴天")

        let candidate2 = FileNameHeuristicParser.parse(fileName: "04. 晴天.flac")
        #expect(candidate2.trackNumber == 4)
        #expect(candidate2.title == "晴天")

        let candidate3 = FileNameHeuristicParser.parse(fileName: "04-晴天.wav")
        #expect(candidate3.trackNumber == 4)
        #expect(candidate3.title == "晴天")
    }

    @Test
    func parseArtistHyphenTitle() {
        let candidate = FileNameHeuristicParser.parse(fileName: "01 - 周杰伦 - 晴天.flac")
        #expect(candidate.trackNumber == 1)
        #expect(candidate.artist == "周杰伦")
        #expect(candidate.title == "晴天")
    }

    @Test
    func parseFullArtistAlbumTitleAndYear() {
        let candidate = FileNameHeuristicParser.parse(fileName: "周杰伦 - 叶惠美 - 04 晴天 (2003).flac")
        #expect(candidate.artist == "周杰伦")
        #expect(candidate.album == "叶惠美")
        #expect(candidate.trackNumber == 4)
        #expect(candidate.title == "晴天")
        #expect(candidate.year == 2003)
    }

    @Test
    func parseRealLibraryLocalAudioFilenames() {
        // 1. Adele track: "Rolling In The Deep.m4a"
        let adele = FileNameHeuristicParser.parse(fileName: "Rolling In The Deep.m4a")
        #expect(adele.title == "Rolling In The Deep")

        // 2. Live track: "03 I Call Ya', Darlin' (live at ATP-NY 2010).mp3"
        let liveTrack = FileNameHeuristicParser.parse(fileName: "03 I Call Ya', Darlin' (live at ATP-NY 2010).mp3")
        #expect(liveTrack.trackNumber == 3)
        #expect(liveTrack.title.contains("I Call Ya'"))
        #expect(liveTrack.title.contains("live at ATP-NY 2010"))

        // 3. EDM track: "Play House - EDM or something.mp3"
        let edm = FileNameHeuristicParser.parse(fileName: "Play House - EDM or something.mp3")
        #expect(edm.artist == "Play House")
        #expect(edm.title == "EDM or something")
    }

    @Test
    func parseComplexFolderMetadataWithSpecs() {
        // 1. 万青 with technical spec & year
        let wq = FileNameHeuristicParser.parseFolderMetadata("万能青年旅店 - 冀西南林路行 (2020)[FLAC 24bit／48khz]")
        #expect(wq.artist == "万能青年旅店")
        #expect(wq.album == "冀西南林路行")
        #expect(wq.year == 2020)

        // 2. Prefixed album folder
        let wqPrefixed = FileNameHeuristicParser.parseFolderMetadata("茶壶专辑 - 万能青年旅店 - 冀西南林路行 (2020) [FLAC 24bit / 48khz]")
        #expect(wqPrefixed.artist == "万能青年旅店")
        #expect(wqPrefixed.album == "冀西南林路行")
        #expect(wqPrefixed.year == 2020)

        // 3. Allan Taylor with (WAV/Cue)
        let at = FileNameHeuristicParser.parseFolderMetadata("Allan Taylor - Looking for You (WAV/Cue)")
        #expect(at.artist == "Allan Taylor")
        #expect(at.album == "Looking for You")

        // 4. Audiophile gold master
        let ld = FileNameHeuristicParser.parseFolderMetadata("刘达 - 甄选2024(24K金碟头版限量)")
        #expect(ld.artist == "刘达")
        #expect(ld.album == "甄选2024")

        // 5. Test parse(fileURL:) integration with real user directory (万青)
        let fileURL = URL(fileURLWithPath: "/Volumes/Music/茶壶专辑 - 万能青年旅店 - 冀西南林路行 (2020)[FLAC 24bit／48khz]/01 - 早.flac")
        let parsed = FileNameHeuristicParser.parse(fileURL: fileURL)
        #expect(parsed.artist == "万能青年旅店")
        #expect(parsed.album == "冀西南林路行")
        #expect(parsed.title == "早")
        #expect(parsed.trackNumber == 1)
        #expect(parsed.year == 2020)

        // 6. Test parse(fileURL:) integration with real user directory inside "男歌手" (Allan Taylor)
        let atURL = URL(fileURLWithPath: "/Volumes/Music/1.歌曲/男歌手/Allan Taylor - Looking for You (WAV/Cue)/Allan Taylor - 01.The Traveler.flac")
        let atParsed = FileNameHeuristicParser.parse(fileURL: atURL)
        #expect(atParsed.artist == "Allan Taylor")
        #expect(atParsed.album == "Looking for You")
        #expect(atParsed.title == "The Traveler")
        #expect(atParsed.trackNumber == 1)
    }
}
