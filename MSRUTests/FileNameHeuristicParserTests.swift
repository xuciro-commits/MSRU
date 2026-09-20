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
}
