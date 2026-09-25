import Foundation
import Testing
import GRDB
@testable import MusicLibrary
@testable import MusicDomain

@Suite("Library health scan")
struct LibraryHealthTests {

    // MARK: - Rules

    @Test("Placeholder titles are recognized without flagging real titles")
    func placeholderTitles() {
        #expect(LibraryHealthRules.isPlaceholderTitle("Track 05", fileStem: "x"))
        #expect(LibraryHealthRules.isPlaceholderTitle("track05", fileStem: "x"))
        #expect(LibraryHealthRules.isPlaceholderTitle("音轨 3", fileStem: "x"))
        #expect(LibraryHealthRules.isPlaceholderTitle("Untitled", fileStem: "x"))
        #expect(LibraryHealthRules.isPlaceholderTitle("", fileStem: "x"))
        #expect(LibraryHealthRules.isPlaceholderTitle(nil, fileStem: "x"))
        #expect(LibraryHealthRules.isPlaceholderTitle("05", fileStem: "05"))
        #expect(LibraryHealthRules.isPlaceholderTitle("01 - Hotel California", fileStem: "01 - Hotel California"))

        #expect(!LibraryHealthRules.isPlaceholderTitle("22", fileStem: "05 22"))
        #expect(!LibraryHealthRules.isPlaceholderTitle("1999", fileStem: "1999"))
        #expect(!LibraryHealthRules.isPlaceholderTitle("Song 2", fileStem: "02 Song 2"))
        #expect(!LibraryHealthRules.isPlaceholderTitle("Hotel California", fileStem: "01 - Hotel California"))
    }

    @Test("Metadata issues cover artist, album and artwork")
    func metadataIssues() {
        let issues = LibraryHealthRules.issues(title: "Track 1", artist: "Unknown Artist", album: nil, artwork: nil, fileStem: "01")
        #expect(issues == [.placeholderTitle, .unknownArtist, .missingAlbum, .missingArtwork])

        let clean = LibraryHealthRules.issues(title: "Wonderwall", artist: "Oasis", album: "(What's the Story) Morning Glory?", artwork: "cover", fileStem: "03 Wonderwall")
        #expect(clean.isEmpty)
    }

    @Test("Duplicate keys ignore case, width, featured artists and version qualifiers")
    func duplicateKeys() {
        let base = LibraryHealthRules.duplicateKey(title: "Hotel California", artist: "Eagles", fileStem: "a")
        #expect(base != nil)
        #expect(LibraryHealthRules.duplicateKey(title: "HOTEL CALIFORNIA (Live)", artist: "eagles", fileStem: "b") == base)
        #expect(LibraryHealthRules.duplicateKey(title: "Hotel California - 2013 Remaster", artist: "Eagles feat. Someone", fileStem: "c") == base)
        #expect(LibraryHealthRules.duplicateKey(title: "Ｈｏｔｅｌ Ｃａｌｉｆｏｒｎｉａ", artist: "Eagles", fileStem: "d") == base)
        #expect(LibraryHealthRules.duplicateKey(title: "New Kid in Town", artist: "Eagles", fileStem: "e") != base)
        #expect(LibraryHealthRules.duplicateKey(title: "Track 3", artist: "Eagles", fileStem: "03") == nil)
        #expect(LibraryHealthRules.duplicateKey(title: "Hotel California", artist: "Unknown Artist", fileStem: "f") == nil)
    }

    @Test("Candidates split by duration")
    func durationPartition() {
        func track(_ path: String, _ duration: TimeInterval) -> LibraryHealthTrack {
            LibraryHealthTrack(path: path, title: "T", artist: "A", duration: duration, format: "FLAC", bitrateKbps: nil, fileSize: 1)
        }
        let runs = LibraryHealthRules.partitionByDuration([track("a", 200), track("b", 420), track("c", 203)])
        #expect(runs.map { $0.map(\.path) } == [["a", "c"], ["b"]])
    }

    // MARK: - Scan

    @Test("Scan reads the index and finds duplicates, incomplete info and missing artwork")
    func scanFindsIssues() async throws {
        let db = try AppDatabase.makeEphemeral()
        let source = SourceID.defaultLocal
        try await db.dbWriter.write { db in
            try db.execute(
                sql: "INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at) VALUES (?, 'local_folder', 'file:///', 'Local', 1, 1, ?, ?)",
                arguments: [source.rawValue, Date(), Date()]
            )
            let eagles = ArtistID("art_eagles")
            let unknown = ArtistID("art_unknown")
            let album = ReleaseID("rel_hotel")
            let recordings: [(RecordingID, String, Double, ArtistID, ReleaseID?)] = [
                (RecordingID("rec_1"), "Hotel California", 390, eagles, album),
                (RecordingID("rec_2"), "Hotel California", 391, eagles, album),
                (RecordingID("rec_live"), "Hotel California (Live)", 420, eagles, album),
                (RecordingID("rec_track05"), "Track 05", 200, unknown, nil)
            ]
            try IdentityRepository.batchUpsertEntities(
                artists: [(id: eagles, name: "Eagles"), (id: unknown, name: "Unknown Artist")],
                recordings: recordings.map { (id: $0.0, title: $0.1, duration: $0.2) },
                releaseGroups: [(id: ReleaseGroupID("rg_hotel"), title: "Hotel California")],
                releases: [(id: album, releaseGroupID: ReleaseGroupID("rg_hotel"), title: "Hotel California", year: 1976, artworkAssetID: "cover_hotel")],
                releaseTracks: recordings.enumerated().compactMap { index, recording in
                    recording.4.map { (id: ReleaseTrackID("trk_\(index)"), releaseID: $0, trackNumber: index + 1, title: recording.1, duration: recording.2, recordingID: recording.0) }
                },
                artistCredits: recordings.map { (artistID: $0.3, entityType: "recording", entityID: $0.0.rawValue) },
                in: db
            )
            let paths = ["/m/a.flac", "/m/b.mp3", "/m/live.flac", "/m/05.mp3"]
            try AssetRepository.batchUpsert(zip(paths, recordings).map { path, recording in
                PersistedAssetRecord(
                    id: AssetID("ast_\(recording.0.rawValue)"), sourceID: source, relativePath: path,
                    fileSize: 1_000, mtime: 1, format: path.hasSuffix("flac") ? "FLAC" : "MP3",
                    duration: recording.2, recordingID: recording.0
                )
            }, in: db)
        }

        let report = try await LibraryHealthScanner(db: db).scan()

        #expect(report.trackCount == 4)
        #expect(report.duplicateGroups.count == 1)
        #expect(Set(report.duplicateCandidatePaths) == ["/m/a.flac", "/m/b.mp3"])
        #expect(report.possibleExtraCopies == 1)
        #expect(report.incompleteInfoPaths == ["/m/05.mp3"])
        #expect(report.missingArtworkPaths == ["/m/05.mp3"])
        #expect(report.placeholderTitleCount == 1)
        #expect(report.unknownArtistCount == 1)
        #expect(report.missingAlbumCount == 1)
    }
}
