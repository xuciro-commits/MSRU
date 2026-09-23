import Foundation
import Testing
import AppFoundation
@testable import MSRU

@Suite("Spotlight indexing contracts")
struct SpotlightIndexingTests {
    actor RecordingWriter: SpotlightIndexWriting {
        var removals = 0
        var removedIDs: [String] = []
        var batches: [[SpotlightMusicRecord]] = []

        func removeLocalMusic() async throws { removals += 1 }
        func remove(ids: [String]) async throws { removedIDs.append(contentsOf: ids) }
        func index(_ records: [SpotlightMusicRecord]) async throws { batches.append(records) }

        func snapshot() -> (Int, [String], [[SpotlightMusicRecord]]) { (removals, removedIDs, batches) }
    }

    @Test("Stable IDs round-trip, including file URLs containing colons")
    func identifiers() {
        let values: [SpotlightMusicID] = [
            .track("file:///Music/A%20Song.flac"),
            .album("Artist — Album"),
            .artist("Artist")
        ]
        for value in values {
            #expect(SpotlightMusicID(rawValue: value.rawValue) == value)
        }
        #expect(SpotlightMusicID(rawValue: "unknown:item") == nil)
        #expect(SpotlightMusicID(rawValue: "track:") == nil)
    }

    @Test("Rebuild removes stale items and indexes local songs, albums and artists in batches")
    func rebuild() async throws {
        let track = LocalTrack(fileURL: URL(fileURLWithPath: "/tmp/spotlight-test.flac"), title: "Song", artist: "Artist", album: "Album")
        let album = AlbumPresentationModel(id: "Artist — Album", title: "Album", artist: "Artist", trackCount: 1, duration: 180)
        let artist = ArtistPresentationModel(id: "Artist", name: "Artist")
        let writer = RecordingWriter()
        let worker = SpotlightIndexWorker(writer: writer, batchSize: 2)

        try await worker.rebuild(SpotlightMusicSnapshot(tracks: [track], albums: [album], artists: [artist]))
        let first = await writer.snapshot()
        #expect(first.0 == 1)
        #expect(first.2.map(\.count) == [2, 1])
        #expect(first.2.flatMap { $0 }.map(\.id) == [.track(track.id), .album(album.id), .artist(artist.id)])

        try await worker.rebuild(SpotlightMusicSnapshot(tracks: [track], albums: [album], artists: [artist]))
        let unchanged = await writer.snapshot()
        #expect(unchanged.0 == 1)
        #expect(unchanged.2.count == 2)

        try await worker.rebuild(SpotlightMusicSnapshot(tracks: [], albums: [], artists: []))
        let second = await writer.snapshot()
        #expect(second.0 == 1)
        #expect(Set(second.1) == Set([SpotlightMusicID.track(track.id).rawValue, SpotlightMusicID.album(album.id).rawValue, SpotlightMusicID.artist(artist.id).rawValue]))
        #expect(second.2.count == 2)
    }

    @Test("Shortcuts select exact tracks and bound search results")
    func intentLookup() {
        let first = LocalTrack(fileURL: URL(fileURLWithPath: "/tmp/song-a.flac"), title: "Song", artist: "One")
        let second = LocalTrack(fileURL: URL(fileURLWithPath: "/tmp/song-b.flac"), title: "Song", artist: "Two")
        #expect(MusicIntentLibrarySearch.exactTrack(title: " song ", artist: "two", in: [first, second])?.id == second.id)
        #expect(MusicIntentLibrarySearch.exactTrack(title: "Song", artist: nil, in: [first, second]) == nil)
        #expect(MusicIntentLibrarySearch.exactTrack(title: "missing", artist: nil, in: [first, second]) == nil)
        #expect(MusicIntentLibrarySearch.results(for: "song", in: [first, second], limit: 1) == ["Song — One"])
        #expect(MusicIntentLibrarySearch.results(for: " ", in: [first, second]).isEmpty)
    }
}
