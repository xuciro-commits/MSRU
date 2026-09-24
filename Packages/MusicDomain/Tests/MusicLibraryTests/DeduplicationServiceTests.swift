import Foundation
import Testing
@testable import MusicLibrary
@testable import MusicDomain

@Suite("Library Deduplication & Version Finder Tests")
struct DeduplicationServiceTests {

    @Test("AudioQualityScore ranks lossless and hi-res above lossy")
    func testAudioQualityScoreOrdering() {
        let hiRes = AudioQualityScore(isLossless: true, sampleRate: 96000, bitDepthBits: 24, bitrateKbps: 2800)
        let cdLossless = AudioQualityScore(isLossless: true, sampleRate: 44100, bitDepthBits: 16, bitrateKbps: 900)
        let highBitrateMP3 = AudioQualityScore(isLossless: false, sampleRate: 44100, bitDepthBits: 16, bitrateKbps: 320)
        let lowBitrateMP3 = AudioQualityScore(isLossless: false, sampleRate: 44100, bitDepthBits: 16, bitrateKbps: 128)

        #expect(hiRes > cdLossless)
        #expect(cdLossless > highBitrateMP3)
        #expect(highBitrateMP3 > lowBitrateMP3)
    }

    @Test("LibraryDeduplicationService detects identical files as fileDuplicate")
    func testExactFileDuplicateDetection() async {
        let service = LibraryDeduplicationService()

        let track1 = LocalTrack(
            fileURL: URL(fileURLWithPath: "/Music/Artist/Song.flac"),
            title: "Hotel California",
            artist: "Eagles",
            album: "Hotel California",
            duration: 390.0
        )
        let track2 = LocalTrack(
            fileURL: URL(fileURLWithPath: "/Music/Downloads/Song_Copy.flac"),
            title: "Hotel California",
            artist: "Eagles",
            album: "Hotel California",
            duration: 390.0
        )

        let report = await service.analyze(tracks: [track1, track2])
        #expect(report.clusters.count == 1)
        if let cluster = report.clusters.first {
            #expect(cluster.title == "Hotel California")
            #expect(cluster.artist == "Eagles")
            #expect(cluster.category == .fileDuplicate)
            #expect(cluster.items.count == 2)
            #expect(cluster.primaryItem != nil)
            #expect(cluster.redundantItems.count == 1)
        }
    }

    @Test("LibraryDeduplicationService detects format variants as differentEncoding")
    func testDifferentEncodingDetection() async {
        let service = LibraryDeduplicationService()

        let flacTrack = LocalTrack(
            fileURL: URL(fileURLWithPath: "/Music/Artist/Song.flac"),
            title: "Billie Jean",
            artist: "Michael Jackson",
            album: "Thriller",
            duration: 294.0
        )
        let mp3Track = LocalTrack(
            fileURL: URL(fileURLWithPath: "/Music/Phone/Song.mp3"),
            title: "Billie Jean",
            artist: "Michael Jackson",
            album: "Thriller",
            duration: 294.0
        )

        let report = await service.analyze(tracks: [flacTrack, mp3Track])
        #expect(report.clusters.count == 1)
        if let cluster = report.clusters.first {
            #expect(cluster.category == .differentEncoding)
            #expect(cluster.items.count == 2)
            // Lossless FLAC must be primary
            #expect(cluster.primaryItem?.track.fileURL.pathExtension == "flac")
            #expect(cluster.redundantItems.first?.track.fileURL.pathExtension == "mp3")
        }
    }
}
