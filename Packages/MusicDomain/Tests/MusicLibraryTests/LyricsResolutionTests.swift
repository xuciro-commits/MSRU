import Foundation
import Testing
@testable import MusicLibrary

@Suite("Lyrics Resolution & Helpers")
struct LyricsResolutionTests {

    @Test("Track title cleaning strips common noise tags")
    func testTrackTitleCleaning() {
        #expect(LrcLibClient.cleanTrackTitle("拒絕再玩 (Live)") == "拒絕再玩")
        #expect(LrcLibClient.cleanTrackTitle("拒絕再玩 [2024 Remaster]") == "拒絕再玩")
        #expect(LrcLibClient.cleanTrackTitle("Hotel California - 2013 Remaster") == "Hotel California")
        #expect(LrcLibClient.cleanTrackTitle("Track Name (feat. Someone)") == "Track Name")
        #expect(LrcLibClient.cleanTrackTitle("Simple Song") == "Simple Song")
    }

    @Test("Artist name cleaning extracts primary artist")
    func testArtistNameCleaning() {
        #expect(LrcLibClient.cleanArtistName("Artist A feat. Artist B") == "Artist A")
        #expect(LrcLibClient.cleanArtistName("Artist A / Artist B") == "Artist A")
        #expect(LrcLibClient.cleanArtistName("Artist A & Artist B") == "Artist A")
        #expect(LrcLibClient.cleanArtistName("陳果") == "陳果")
    }

    @Test("Chinese script variants generates Hans and Hant")
    func testScriptVariants() {
        let variants = LrcLibClient.scriptVariants(for: "拒絕再玩")
        #expect(variants.contains("拒絕再玩"))
        #expect(variants.contains("拒绝再玩"))
    }

    @Test("Best candidate selects synced lyrics and matches closest duration")
    func testBestCandidateSelection() {
        let c1 = LrcLibResponse(id: 1, duration: 213, syncedLyrics: "[00:01.00] lyric 1")
        let c2 = LrcLibResponse(id: 2, duration: 320, syncedLyrics: "[00:01.00] lyric 2")
        let c3 = LrcLibResponse(id: 3, duration: 230, plainLyrics: "plain lyric 3")

        // Target duration is 215s; c1 is closest synced candidate (|213 - 215| = 2)
        let best = LrcLibClient.bestCandidate(from: [c1, c2, c3], targetDuration: 215)
        #expect(best?.id == 1)

        // Prefer synced candidate even if plain candidate has slightly closer duration
        let bestSynced = LrcLibClient.bestCandidate(from: [c1, c2, c3], targetDuration: 228)
        #expect(bestSynced?.id == 1)
    }
}
