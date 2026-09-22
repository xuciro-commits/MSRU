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

        // 7. Test loose track inside an artist folder does NOT produce album == artist
        let jayURL = URL(fileURLWithPath: "/Volumes/团队文件-home.zhuhai/03 音乐资源/音乐/1.歌曲/男歌手/周杰伦/周杰伦 - 愛在西元前.wav")
        let jayParsed = FileNameHeuristicParser.parse(fileURL: jayURL)
        #expect(jayParsed.artist == "周杰伦")
        #expect(jayParsed.album == nil) // Disambiguated: 周杰伦 is artist, not album!
        #expect(jayParsed.title == "愛在西元前")

        // 8. Test folder with 《Book Title Brackets》
        let remURL = URL(fileURLWithPath: "/Volumes/1.歌曲/男歌手/R.E.M《The_Best_Of_R.E.M》/01.Man On The Moon.dts")
        let remParsed = FileNameHeuristicParser.parse(fileURL: remURL)
        #expect(remParsed.artist == "R.E.M")
        #expect(remParsed.album == "The_Best_Of_R.E.M")
        #expect(remParsed.title == "Man On The Moon")
        #expect(remParsed.trackNumber == 1)

        // 9. Test artist folder under "华语女" (Priscilla Chan loose DSF)
        let pcURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语女/陈慧娴/陈慧娴 - Snowflake.dsf")
        let pcParsed = FileNameHeuristicParser.parse(fileURL: pcURL)
        #expect(pcParsed.artist == "陈慧娴")
        #expect(pcParsed.album == nil) // Heuristic leaves album nil so DSF ID3 can supply By Heart
        #expect(pcParsed.title == "Snowflake")
    }

    @Test
    func testGenericFolderFiltering() {
        #expect(FileNameHeuristicParser.isGenericFolderName("71-音乐库"))
        #expect(FileNameHeuristicParser.isGenericFolderName("Music"))
        #expect(FileNameHeuristicParser.isGenericFolderName("Unsorted"))
        #expect(FileNameHeuristicParser.isGenericFolderName("01-Download"))
        #expect(FileNameHeuristicParser.isGenericFolderName("新建文件夹"))
        #expect(!FileNameHeuristicParser.isGenericFolderName("21"))
        #expect(!FileNameHeuristicParser.isGenericFolderName("1989"))

        let meta1 = FileNameHeuristicParser.parseFolderMetadata("71-音乐库")
        #expect(meta1.artist == nil)
        #expect(meta1.album == nil)

        let meta2 = FileNameHeuristicParser.parseFolderMetadata("Music")
        #expect(meta2.artist == nil)
        #expect(meta2.album == nil)

        let fileURL = URL(fileURLWithPath: "/Volumes/Music/71-音乐库/2234.mp3")
        let parsed = FileNameHeuristicParser.parse(fileURL: fileURL)
        #expect(parsed.artist == nil)
        #expect(parsed.album == nil)
        #expect(parsed.title == "2234")
    }
}

