//
//  CascadeDeletionTests.swift
//  MSRUTests
//
//  Canonical tests protecting bidirectional cascade deletion,
//  multi-artist collaboration safety, and orphan release/artist garbage collection.
//

import Testing
import Foundation
import AppFoundation
import MusicDomain
import GRDB
import MusicLibrary
import MusicPlayback
@testable import MSRU

private actor InMemoryLibraryRepository: LibraryRepository {
    var tracks: [LibraryTrack] = []
    init(tracks: [LibraryTrack] = []) { self.tracks = tracks }
    func loadTracks() async throws -> [LibraryTrack] { tracks }
    func saveTracks(_ tracks: [LibraryTrack]) async throws { self.tracks = tracks }
}

@MainActor
@Suite("Cascade Deletion & Orphan Garbage Collection Contracts")
struct CascadeDeletionTests {

    @Test
    func artistCreditCleanerParsingAndCollaborationSafety() {
        // Arrange & Act
        let sole1 = "周杰伦"
        let collab1 = "周杰伦, 蔡依林"
        let collab2 = "Eminem feat. Rihanna"
        let collab3 = "Queen & David Bowie"

        // Assert: Parse artists
        #expect(ArtistCreditCleaner.parseArtists(from: sole1) == ["周杰伦"])
        #expect(ArtistCreditCleaner.parseArtists(from: collab1) == ["周杰伦", "蔡依林"])
        #expect(ArtistCreditCleaner.parseArtists(from: collab2) == ["Eminem", "Rihanna"])
        #expect(ArtistCreditCleaner.parseArtists(from: collab3) == ["Queen", "David Bowie"])

        // Assert: Sole vs. Collaboration
        #expect(ArtistCreditCleaner.isSoleArtist("周杰伦", in: sole1))
        #expect(!ArtistCreditCleaner.isSoleArtist("周杰伦", in: collab1))
        #expect(!ArtistCreditCleaner.isSoleArtist("蔡依林", in: collab1))
        #expect(!ArtistCreditCleaner.isSoleArtist("Rihanna", in: collab2))

        // Assert: Removing artist from collaboration
        #expect(ArtistCreditCleaner.removingArtist("周杰伦", from: collab1) == "蔡依林")
        #expect(ArtistCreditCleaner.removingArtist("蔡依林", from: collab1) == "周杰伦")
        #expect(ArtistCreditCleaner.removingArtist("Rihanna", from: collab2) == "Eminem")
        #expect(ArtistCreditCleaner.removingArtist("周杰伦", from: sole1) == nil)
    }

    @Test
    func soleTrackDeletionPrunesOrphanReleaseAndArtist() async throws {
        // Arrange: 1 artist, 1 album, 1 track
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb, id: SourceID("src_cascade_test"))
        let identityRepo = IdentityRepository(db: appDb)
        let assetRepo = AssetRepository(db: appDb)

        let artistID = ArtistID("art_jay")
        try await identityRepo.upsertArtist(id: artistID, name: "周杰伦")

        let releaseID = ReleaseID("rel_yehuimei")
        try await identityRepo.upsertRelease(id: releaseID, title: "叶惠美")

        let recID = RecordingID("rec_qingtian")
        try await identityRepo.upsertRecording(id: recID, title: "晴天")

        let rtID = ReleaseTrackID("rt_qingtian")
        try await identityRepo.upsertReleaseTrack(
            id: rtID,
            releaseID: releaseID,
            mediumPosition: 1,
            trackPosition: 1,
            trackNumber: "1",
            title: "晴天",
            recordingID: recID
        )

        let assetID = AssetID("asset_qingtian")
        let asset = PersistedAssetRecord(
            id: assetID,
            sourceID: sourceID,
            relativePath: "Jay/YeHuiMei/01. 晴天.flac",
            fileSize: 2048,
            mtime: 1000.0,
            format: "FLAC",
            recordingID: recID
        )
        try await assetRepo.batchUpsert([asset])

        try await identityRepo.insertArtistCredit(artistID: artistID, entityType: "recording", entityID: recID.rawValue)
        try await identityRepo.insertArtistCredit(artistID: artistID, entityType: "release", entityID: releaseID.rawValue)

        // Act: Delete the single track by relative path
        let (prunedReleases, prunedArtists) = try await identityRepo.deleteTracks(
            relativePaths: ["Jay/YeHuiMei/01. 晴天.flac"]
        )

        // Assert: 1 release was pruned, 1 artist was pruned
        #expect(prunedReleases == 1)
        #expect(prunedArtists == 1)

        // Verify SQLite state: Release is gone, Artist is gone, Recording is gone
        try await appDb.reader.read { db in
            let relCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM releases WHERE id = ?", arguments: [releaseID.rawValue]) ?? 0
            #expect(relCount == 0)

            let artCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists WHERE id = ?", arguments: [artistID.rawValue]) ?? 0
            #expect(artCount == 0)

            let recCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recordings WHERE id = ?", arguments: [recID.rawValue]) ?? 0
            #expect(recCount == 0)

            let assetCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets WHERE id = ?", arguments: [assetID.rawValue]) ?? 0
            #expect(assetCount == 0)
        }
    }

    @Test
    func artistDeletionPreservesCollaborationsAndCleansCredits() async throws {
        // Arrange: Artist Jay and Artist Jolin
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb, id: SourceID("src_collab_test"))
        let identityRepo = IdentityRepository(db: appDb)
        let assetRepo = AssetRepository(db: appDb)

        let artJay = ArtistID("art_jay")
        let artJolin = ArtistID("art_jolin")
        try await identityRepo.upsertArtist(id: artJay, name: "周杰伦")
        try await identityRepo.upsertArtist(id: artJolin, name: "蔡依林")

        // Track 1: Sole Jay track ("晴天")
        let recSole = RecordingID("rec_qingtian")
        try await identityRepo.upsertRecording(id: recSole, title: "晴天")
        let assetSole = PersistedAssetRecord(
            id: AssetID("asset_sole"),
            sourceID: sourceID,
            relativePath: "Jay/01. 晴天.flac",
            fileSize: 1024,
            mtime: 1000.0,
            format: "FLAC",
            recordingID: recSole
        )
        try await assetRepo.batchUpsert([assetSole])

        // Track 2: Collaboration Jay & Jolin ("布拉格广场")
        let recCollab = RecordingID("rec_prague")
        try await identityRepo.upsertRecording(id: recCollab, title: "布拉格广场")
        let assetCollab = PersistedAssetRecord(
            id: AssetID("asset_collab"),
            sourceID: sourceID,
            relativePath: "Collab/02. 布拉格广场.flac",
            fileSize: 1024,
            mtime: 1000.0,
            format: "FLAC",
            recordingID: recCollab
        )
        try await assetRepo.batchUpsert([assetCollab])

        try await identityRepo.insertArtistCredit(artistID: artJay, entityType: "recording", entityID: recSole.rawValue)
        try await identityRepo.insertArtistCredit(artistID: artJay, entityType: "recording", entityID: recCollab.rawValue)
        try await identityRepo.insertArtistCredit(artistID: artJolin, entityType: "recording", entityID: recCollab.rawValue)

        // Act: Delete Artist Jay
        _ = try await identityRepo.deleteArtist(id: artJay)

        // Assert:
        // 1. Sole track (晴天) is deleted
        // 2. Collab track (布拉格广场) is preserved!
        // 3. Jay's credit on collab is removed, Jolin's credit remains!
        // 4. Jay is deleted, Jolin is preserved!
        try await appDb.reader.read { db in
            let soleRecCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recordings WHERE id = ?", arguments: [recSole.rawValue]) ?? 0
            #expect(soleRecCount == 0)

            let collabRecCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recordings WHERE id = ?", arguments: [recCollab.rawValue]) ?? 0
            #expect(collabRecCount == 1)

            let jayCredits = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artist_credits WHERE artist_id = ?", arguments: [artJay.rawValue]) ?? 0
            #expect(jayCredits == 0)

            let jolinCredits = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artist_credits WHERE artist_id = ? AND entity_id = ?", arguments: [artJolin.rawValue, recCollab.rawValue]) ?? 0
            #expect(jolinCredits == 1)

            let jayCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists WHERE id = ?", arguments: [artJay.rawValue]) ?? 0
            #expect(jayCount == 0)

            let jolinCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists WHERE id = ?", arguments: [artJolin.rawValue]) ?? 0
            #expect(jolinCount == 1)
        }
    }

    @Test
    func albumDeletionPrunesOrphanArtistIfNoOtherWorksExist() async throws {
        // Arrange: Artist with 1 album and 2 tracks
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb, id: SourceID("src_album_prune"))
        let identityRepo = IdentityRepository(db: appDb)
        let assetRepo = AssetRepository(db: appDb)

        let artID = ArtistID("art_alone")
        try await identityRepo.upsertArtist(id: artID, name: "单专歌手")

        let relID = ReleaseID("rel_only_one")
        try await identityRepo.upsertRelease(id: relID, title: "唯一专辑")

        let rec1 = RecordingID("rec_1")
        let rec2 = RecordingID("rec_2")
        try await identityRepo.upsertRecording(id: rec1, title: "Track 1")
        try await identityRepo.upsertRecording(id: rec2, title: "Track 2")

        let rt1 = ReleaseTrackID("rt_1")
        let rt2 = ReleaseTrackID("rt_2")
        try await identityRepo.upsertReleaseTrack(
            id: rt1,
            releaseID: relID,
            mediumPosition: 1,
            trackPosition: 1,
            trackNumber: "1",
            title: "Track 1",
            recordingID: rec1
        )
        try await identityRepo.upsertReleaseTrack(
            id: rt2,
            releaseID: relID,
            mediumPosition: 1,
            trackPosition: 2,
            trackNumber: "2",
            title: "Track 2",
            recordingID: rec2
        )

        let asset1 = PersistedAssetRecord(id: AssetID("a1"), sourceID: sourceID, relativePath: "Album/01.flac", fileSize: 100, mtime: 1.0, format: "FLAC", recordingID: rec1)
        let asset2 = PersistedAssetRecord(id: AssetID("a2"), sourceID: sourceID, relativePath: "Album/02.flac", fileSize: 100, mtime: 1.0, format: "FLAC", recordingID: rec2)
        try await assetRepo.batchUpsert([asset1, asset2])

        try await identityRepo.insertArtistCredit(artistID: artID, entityType: "recording", entityID: rec1.rawValue)
        try await identityRepo.insertArtistCredit(artistID: artID, entityType: "recording", entityID: rec2.rawValue)
        try await identityRepo.insertArtistCredit(artistID: artID, entityType: "release", entityID: relID.rawValue)

        // Act: Delete the release
        let (_, prunedArtists) = try await identityRepo.deleteRelease(id: relID)

        // Assert: Artist has no other tracks or releases, so artist was pruned!
        #expect(prunedArtists == 1)

        try await appDb.reader.read { db in
            let artCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists WHERE id = ?", arguments: [artID.rawValue]) ?? 0
            #expect(artCount == 0)

            let relCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM releases WHERE id = ?", arguments: [relID.rawValue]) ?? 0
            #expect(relCount == 0)
        }
    }

    @Test
    func crossStorePurgeSync() async {
        // Arrange
        let playlistStore = PlaylistStore(repository: PreviewPlaylistRepository(playlists: []))
        let libraryStore = LibraryStore(repository: InMemoryLibraryRepository())
        let playbackController = PlaybackController()

        // 1. Create a playlist with track "track_test_123"
        let pl = await playlistStore.createPlaylist(title: "My Favorite Playlist", initialTrackIDs: ["track_test_123", "track_keep_456"])
        #expect(pl.trackIDs.count == 2)

        // 2. Add to library
        let fileURL = URL(fileURLWithPath: "/music/test_123.flac")
        let localTrack = LocalTrack(fileURL: fileURL, title: "Test Song", artist: "Artist", duration: 180)
        await libraryStore.add(local: localTrack)
        let remoteSource = LibraryPlaybackSource(kind: .openverse, externalID: "remote-copy")
        if let savedID = libraryStore.libraryTrack(for: localTrack)?.id {
            #expect(await libraryStore.addSource(remoteSource, toTrackID: savedID))
        }
        #expect(libraryStore.contains(local: localTrack))

        // 3. Add to playback queue
        let playItem = PlaybackItem(local: localTrack)
        playbackController.addToQueue(playItem)
        #expect(playbackController.playbackQueue.upcoming.count == 1)

        // Act: Purge across all 3 stores
        await playlistStore.purgeTracks(withIDs: ["track_test_123"])
        await libraryStore.purgeTracks(matchingIDs: ["track_test_123"], localURLs: [fileURL])
        playbackController.purgeTracks(withIDs: ["track_test_123"], localURLs: [fileURL])

        // Assert:
        // Playlist now only has "track_keep_456"
        let updatedPL = playlistStore.playlists.first { $0.id == pl.id }
        #expect(updatedPL?.trackIDs == ["track_keep_456"])

        // Library no longer contains the track
        #expect(!libraryStore.contains(local: localTrack))
        #expect(libraryStore.contains(source: remoteSource))

        // Playback queue is cleared
        #expect(playbackController.playbackQueue.upcoming.isEmpty)
    }

    @Test
    func localDeletionCascadesCollectionsAndRollsBackOnFailure() async throws {
        let db = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: db)
        let path = "/tmp/msru-cascade-atomic.flac"
        let recordingID = RecordingID("rec_atomic_cascade")
        let assetID = AssetID("asset_atomic_cascade")
        try await IdentityRepository(db: db).upsertRecording(id: recordingID, title: "Atomic")
        try await AssetRepository(db: db).batchUpsert([
            PersistedAssetRecord(id: assetID, sourceID: sourceID, relativePath: path,
                                 fileSize: 100, mtime: 1, format: "FLAC", recordingID: recordingID)
        ])
        let saved = LibraryTrack(title: "Atomic", artist: "Artist", sources: [
            LibraryPlaybackSource(kind: .local, localFileURL: URL(fileURLWithPath: path)),
            LibraryPlaybackSource(kind: .openverse, externalID: "remote-copy")
        ])
        let savedRepository = SQLiteLibraryRepository(db: db)
        try await savedRepository.saveTracks([saved])
        let playlist = Playlist(title: "Atomic", trackIDs: [path, "keep"])
        let playlistRepository = SQLitePlaylistRepository(db: db)
        try await playlistRepository.savePlaylists([playlist])

        try await db.dbWriter.write { database in
            try database.execute(sql: "CREATE TRIGGER reject_atomic_delete BEFORE DELETE ON assets BEGIN SELECT RAISE(ABORT, 'injected failure'); END")
        }
        let localRepository = SQLiteLocalLibraryRepository(db: db)
        await #expect(throws: (any Error).self) {
            try await localRepository.deleteTracks(withIDs: [path], deletePhysicalFiles: false)
        }
        let before = try await savedRepository.loadTracks()
        #expect(before.first?.sources.count == 2)
        #expect(try await playlistRepository.loadPlaylists().first?.trackIDs == [path, "keep"])

        try await db.dbWriter.write { database in
            try database.execute(sql: "DROP TRIGGER reject_atomic_delete")
        }
        try await localRepository.deleteTracks(withIDs: [path], deletePhysicalFiles: false)
        let after = try await savedRepository.loadTracks()
        #expect(after.first?.sources.map(\.kind) == [.openverse])
        #expect(try await playlistRepository.loadPlaylists().first?.trackIDs == ["keep"])
        let assetCount = try await db.reader.read { database in
            try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM assets WHERE id = ?", arguments: [assetID.rawValue]) ?? 0
        }
        #expect(assetCount == 0)
    }

    @Test
    func reconcileLocalAssetsPrunesZombiesAndOrphanReleasesArtists() async throws {
        let appDb = try TestDatabase.makeEphemeral()
        let sourceID = try await TestDatabase.seedSource(in: appDb, id: SourceID("src_local_default"))
        let identityRepo = IdentityRepository(db: appDb)
        let assetRepo = AssetRepository(db: appDb)

        let artistID = ArtistID("art_zombie")
        try await identityRepo.upsertArtist(id: artistID, name: "张学友")

        let releaseID = ReleaseID("rel_zombie")
        try await identityRepo.upsertRelease(id: releaseID, title: "313240672581865")

        let recID = RecordingID("rec_zombie")
        try await identityRepo.upsertRecording(id: recID, title: "遥远的她-48k")

        let rtID = ReleaseTrackID("rt_zombie")
        try await identityRepo.upsertReleaseTrack(
            id: rtID,
            releaseID: releaseID,
            mediumPosition: 1,
            trackPosition: 1,
            trackNumber: "1",
            title: "遥远的她-48k",
            recordingID: recID
        )

        let assetID = AssetID("ast_zombie")
        let asset = PersistedAssetRecord(
            id: assetID,
            sourceID: sourceID,
            relativePath: "/private/var/mobile/Containers/Shared/AppGroup/UUID/File Provider Storage/张学友 - 遥远的她-48k.mp3",
            fileSize: 1024,
            mtime: 1000.0,
            format: "MP3",
            recordingID: recID
        )
        try await assetRepo.batchUpsert([asset])

        try await identityRepo.insertArtistCredit(artistID: artistID, entityType: "recording", entityID: recID.rawValue)
        try await identityRepo.insertArtistCredit(artistID: artistID, entityType: "release", entityID: releaseID.rawValue)

        // Act: Reconcile with an empty active track set (user deleted songs externally or previously)
        let (prunedReleases, prunedArtists) = try await identityRepo.reconcileLocalAssets(
            validPaths: [],
            validFilenames: [],
            validRecordingIDs: []
        )

        #expect(prunedReleases == 1)
        #expect(prunedArtists == 1)

        try await appDb.reader.read { db in
            let artCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists WHERE id = ?", arguments: [artistID.rawValue]) ?? 0
            #expect(artCount == 0)

            let relCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM releases WHERE id = ?", arguments: [releaseID.rawValue]) ?? 0
            #expect(relCount == 0)

            let recCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recordings WHERE id = ?", arguments: [recID.rawValue]) ?? 0
            #expect(recCount == 0)

            let astCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets WHERE id = ?", arguments: [assetID.rawValue]) ?? 0
            #expect(astCount == 0)
        }
    }
}
