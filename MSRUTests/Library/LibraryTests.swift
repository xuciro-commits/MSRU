//
//  LibraryTests.swift
//  MSRUTests
//
//  Canonical library tests protecting user library persistence (favorites, overrides),
//  and deduplication classification contracts (binary duplicate, quality tiering, live vs studio).
//

import Testing
import Foundation
import AppFoundation
import MusicDomain
import GRDB
import AVFoundation
import MusicLibrary
@testable import MSRU

@Suite("Library & Deduplication Invariants")
struct LibraryTests {

    @Test
    func userLibraryRepositoryTogglesFavorite() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let identityRepo = IdentityRepository(db: appDb)
        let userLibRepo = UserLibraryRepository(db: appDb)

        let recID = RecordingID("rec_fav_test")
        try await identityRepo.upsertRecording(id: recID, title: "晴天")

        // Act 1: Initial add to library with isFavorite = false
        try await userLibRepo.addLibraryEntry(recordingID: recID, isFavorite: false)
        let initialFav = try await userLibRepo.isFavorite(recordingID: recID)
        #expect(!initialFav)

        // Act 2: Set favorite to true
        try await userLibRepo.setFavorite(recordingID: recID, isFavorite: true)

        // Assert: Favorite state is persisted
        let toggledFav = try await userLibRepo.isFavorite(recordingID: recID)
        #expect(toggledFav)
        let totalCount = try await userLibRepo.totalEntriesCount()
        #expect(totalCount == 1)
    }

    @Test
    func userLibraryRepositoryPersistsMetadataOverrides() async throws {
        // Arrange
        let appDb = try TestDatabase.makeEphemeral()
        let userLibRepo = UserLibraryRepository(db: appDb)
        let recID = RecordingID("rec_override_test")

        // Act: Set manual user override
        try await userLibRepo.setMetadataOverride(
            entityType: "recording",
            entityID: recID.rawValue,
            field: "title",
            value: "晴天 (2024 Remaster)"
        )

        // Assert: Override is stored in user_metadata_overrides table
        let overrideVal: String? = try await appDb.reader.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT override_value FROM user_metadata_overrides WHERE entity_type = ? AND entity_id = ? AND field = ?",
                arguments: ["recording", recID.rawValue, "title"]
            )
        }
        #expect(overrideVal == "晴天 (2024 Remaster)")
    }

    @Test
    func duplicateClassifierCategorizesExactBinaryMatch() {
        // Arrange: Two assets with identical SHA256 checksums
        let assetA = AudioAsset(
            id: "ast_1",
            fileURL: URL(fileURLWithPath: "/music/folder1/track.flac"),
            fileSize: 30000,
            sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            format: "FLAC"
        )
        let assetB = AudioAsset(
            id: "ast_2",
            fileURL: URL(fileURLWithPath: "/music/folder2/track.flac"),
            fileSize: 30000,
            sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            format: "FLAC"
        )

        // Act
        let result = DuplicateClassifier.classify(assetA: assetA, assetB: assetB)

        // Assert: File duplicate detected, safe to merge
        #expect(result.category == .fileDuplicate)
        #expect(result.category.isSafeToMerge)
    }

    @Test
    func duplicateClassifierCategorizesQualityDifferenceAndElectsHiResMaster() {
        // Arrange: 24/96 Master vs 16/44.1 CD rip of the same recording
        let rec = Fixtures.makeRecording(id: "rec_sunny", title: "晴天")

        let masterAsset = AudioAsset(
            id: "ast_master",
            fileURL: URL(fileURLWithPath: "/music/sunny_24_96.flac"),
            format: "FLAC",
            bitDepth: "24-bit",
            sampleRate: 96000,
            recordingID: rec.id
        )

        let cdAsset = AudioAsset(
            id: "ast_cd",
            fileURL: URL(fileURLWithPath: "/music/sunny_16_44.flac"),
            format: "FLAC",
            bitDepth: "16-bit",
            sampleRate: 44100,
            recordingID: rec.id
        )

        // Act
        let result = DuplicateClassifier.classify(
            assetA: cdAsset,
            recordingA: rec,
            assetB: masterAsset,
            recordingB: rec
        )

        // Assert: Quality difference detected, preferred asset is the 24/96 master
        #expect(result.category == .qualityDifference)
        #expect(result.preferredAssetID == masterAsset.id)
        #expect(!result.category.isSafeToMerge) // Never destroy lower res without user consent
    }

    @Test
    func duplicateClassifierDistinguishesStudioVsLivePerformances() {
        // Arrange: Studio recording vs Live concert capture sharing the same Work
        let work = Fixtures.makeWork(id: "wrk_sunny", title: "晴天")

        let studioRec = Recording(
            id: "rec_studio",
            title: "晴天",
            artistCredit: ArtistCredit(single: Fixtures.makeArtist()),
            workID: work.id,
            isLive: false
        )
        let liveRec = Recording(
            id: "rec_live",
            title: "晴天 (Live 2004)",
            artistCredit: ArtistCredit(single: Fixtures.makeArtist()),
            workID: work.id,
            isLive: true
        )

        let assetStudio = AudioAsset(
            id: "ast_studio",
            fileURL: URL(fileURLWithPath: "/music/studio.flac"),
            format: "FLAC",
            recordingID: studioRec.id
        )
        let assetLive = AudioAsset(
            id: "ast_live",
            fileURL: URL(fileURLWithPath: "/music/live.flac"),
            format: "FLAC",
            recordingID: liveRec.id
        )

        // Act
        let result = DuplicateClassifier.classify(
            assetA: assetStudio,
            recordingA: studioRec,
            workA: work,
            assetB: assetLive,
            recordingB: liveRec,
            workB: work
        )

        // Assert: Different performance must strictly not merge
        #expect(result.category == .differentPerformance)
        #expect(!result.category.isSafeToMerge)
        #expect(!result.category.isSameRecording)
        #expect(result.category.isSameWork)
    }

    @Test("Local manifest migration keeps unreadable input and archives verified input")
    @MainActor
    func localManifestMigrationPreservesAndArchives() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("local_migration_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manifest = directory.appendingPathComponent("external_tracks.json")
        let backup = manifest.appendingPathExtension("legacy.backup")
        let repo = SQLiteLocalLibraryRepository(db: try TestDatabase.makeEphemeral(), directory: directory)

        try Data("{bad".utf8).write(to: manifest)
        await #expect(throws: Error.self) { _ = try await repo.loadTracks() }
        #expect(FileManager.default.fileExists(atPath: manifest.path))
        #expect(!FileManager.default.fileExists(atPath: backup.path))

        let track = LocalTrack(fileURL: directory.appendingPathComponent("kept.wav"),
                               title: "Kept", artist: "Artist", album: "Album", duration: 10)
        let original = try JSONEncoder().encode([track])
        try original.write(to: manifest)
        let loaded = try await repo.loadTracks()
        #expect(loaded.count == 1)
        #expect(loaded[0].title == track.title)
        #expect(!FileManager.default.fileExists(atPath: manifest.path))
        #expect(try Data(contentsOf: backup) == original)
        #expect(try await repo.loadTracks().count == 1)
    }

    @Test("Album and artist track queries stay scoped to their SQLite identities")
    @MainActor
    func localTracksByReleaseAndArtist() async throws {
        let db = try TestDatabase.makeEphemeral()
        let repo = SQLiteLocalLibraryRepository(db: db)
        let first = LocalTrack(fileURL: URL(fileURLWithPath: "/music/a1.wav"),
                               title: "A1", artist: "Artist A", album: "Shared", trackNumber: 1)
        let second = LocalTrack(fileURL: URL(fileURLWithPath: "/music/a2.wav"),
                                title: "A2", artist: "Artist A", album: "Shared", trackNumber: 2)
        let other = LocalTrack(fileURL: URL(fileURLWithPath: "/music/b1.wav"),
                               title: "B1", artist: "Artist B", album: "Shared", trackNumber: 1)
        try await repo.saveTracksInPlace([first, second])
        try await repo.saveTracksInPlace([other])

        let releaseA = DeterministicID.release(artist: "Artist A", title: "Shared").rawValue
        let artistB = DeterministicID.artist(name: "Artist B").rawValue
        let albumTracks = try await repo.fetchTracks(forReleaseIDs: [releaseA])
        #expect(albumTracks.map(\.id) == [first.id, second.id])
        #expect(try await repo.fetchTracks(forArtistIDs: [artistB]).map(\.id) == [other.id])
        #expect(try await repo.fetchTracks(inFolder: URL(fileURLWithPath: "/music")).count == 3)
        #expect(try await repo.fetchTracks(inFolder: URL(fileURLWithPath: "/music-other")).isEmpty)
        #expect(try await repo.findUniqueTrack(title: "a1", artist: "ARTIST A")?.id == first.id)
        #expect(try await repo.searchTracks("Artist A", limit: 1).map(\.id) == [first.id])

        _ = try await IdentityRepository(db: db).deleteRelease(
            id: ReleaseID(releaseA), title: "Shared", artist: "Artist A"
        )
        let releaseB = DeterministicID.release(artist: "Artist B", title: "Shared").rawValue
        #expect(try await repo.fetchTracks(forReleaseIDs: [releaseB]).map(\.id) == [other.id])
    }

    @Test("Deleting one local asset preserves a same-named file in another folder")
    @MainActor
    func localDeletionUsesExactAssetIdentity() async throws {
        let repo = SQLiteLocalLibraryRepository(db: try TestDatabase.makeEphemeral())
        let first = LocalTrack(fileURL: URL(fileURLWithPath: "/music/disc-a/song.wav"),
                               title: "Song", artist: "Artist", album: "Album", trackNumber: 1)
        let second = LocalTrack(fileURL: URL(fileURLWithPath: "/music/disc-b/song.wav"),
                                title: "Song", artist: "Artist", album: "Album", trackNumber: 1)
        try await repo.saveTracksInPlace([first, second])
        try await repo.deleteTracks(withIDs: [first.id], deletePhysicalFiles: false)

        #expect(try await repo.fetchTracks(withIDs: [first.id]).isEmpty)
        #expect(try await repo.fetchTracks(withIDs: [second.id]).map(\.id) == [second.id])
    }

    @Test("Failed local writes keep the visible track and artist credit")
    @MainActor
    func failedLocalMutationsKeepVisibleState() async throws {
        let track = LocalTrack(fileURL: URL(fileURLWithPath: "/music/duet.wav"),
                               title: "Duet", artist: "Alpha & Beta",
                               artworkReference: "cover.jpg")
        let store = LocalLibraryStore(
            repository: FailingLocalMutationRepository(tracks: [track]),
            db: try TestDatabase.makeEphemeral()
        )
        await store.loadIfNeeded()

        await store.deleteArtist(name: "Alpha")
        #expect(store.tracks.first?.artist == "Alpha & Beta")
        #expect(store.errorMessage != nil)

        let removed = await store.deleteTracks(withIDs: [track.id])
        #expect(!removed)
        #expect(store.tracks.map { $0.id } == [track.id])
    }

    @Test("Explicit metadata repair streams pages without loading the whole library")
    @MainActor
    func metadataRepairUsesMaintenancePages() async throws {
        let tracks = (0..<3).map { index in
            LocalTrack(fileURL: URL(fileURLWithPath: "/not-present/\(index).wav"),
                       title: "Song \(index)", artist: "Artist", album: "Artist",
                       artworkReference: "already-present.jpg")
        }
        let repository = PagedMaintenanceRepository(tracks: tracks)
        let store = LocalLibraryStore(repository: repository, db: try TestDatabase.makeEphemeral())
        await store.loadIfNeeded()
        let active = try await store.fingerprintCleanupReferences()
        #expect(active.keys.count == 3)
        #expect(active.paths.count == 3)
        let result = await store.remediateLibraryMetadataAndArtwork()

        #expect(result.repairedCount == 3)
        #expect(result.artworkAddedCount == 0)
        #expect(!store.isFullyLoaded)
        #expect(repository.saved.count == 3)
        #expect(repository.saved.allSatisfy { $0.album == nil })
    }

    @Test("Batch import reports individual failures and retries without duplicating successful files")
    @MainActor
    func partialImportFailureAndRetry() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("msru_import_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = directory.appendingPathComponent("valid.wav")
        let missing = directory.appendingPathComponent("missing.wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128))
        buffer.frameLength = 128
        let file = try AVAudioFile(forWriting: valid, settings: format.settings)
        try file.write(from: buffer)

        let repo = SQLiteLocalLibraryRepository(db: try TestDatabase.makeEphemeral())
        let first = try await repo.importTracksDetailed(from: [valid, missing])
        #expect(first.tracks.count == 1)
        #expect(first.failures.map(\.fileURL) == [missing])
        #expect(try await repo.fetchPage(LocalTrackPageRequest()).totalCount == 1)

        try FileManager.default.copyItem(at: valid, to: missing)
        let retry = try await repo.importTracksDetailed(from: [valid, missing])
        #expect(retry.failures.isEmpty)
        #expect(try await repo.fetchPage(LocalTrackPageRequest()).totalCount == 2)
    }
}

@MainActor
private final class FailingLocalMutationRepository: LocalLibraryRepository {
    let tracks: [LocalTrack]

    init(tracks: [LocalTrack]) { self.tracks = tracks }
    func loadTracks() async throws -> [LocalTrack] { tracks }
    func importTrack(from url: URL) async throws -> LocalTrack? { nil }
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws { throw CocoaError(.fileWriteUnknown) }
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        throw CocoaError(.fileWriteUnknown)
    }
}

@MainActor
private final class PagedMaintenanceRepository: LocalLibraryRepository {
    let source: [LocalTrack]
    var saved: [LocalTrack] = []

    init(tracks: [LocalTrack]) { source = tracks }
    func loadTracks() async throws -> [LocalTrack] { throw CocoaError(.fileReadTooLarge) }
    func fetchPage(_ request: LocalTrackPageRequest) async throws -> LocalTrackPage {
        LocalTrackPage(tracks: Array(source.prefix(1)), totalCount: source.count, offset: 0)
    }
    func fetchMaintenancePage(afterPath: String?, limit: Int) async throws -> LocalMaintenancePage {
        let next = source.filter { track in
            afterPath.map { track.fileURL.path > $0 } ?? true
        }.prefix(1)
        let tracks = Array(next)
        return LocalMaintenancePage(tracks: tracks, nextPath: tracks.last?.fileURL.path)
    }
    func importTrack(from url: URL) async throws -> LocalTrack? { nil }
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws { saved.append(contentsOf: tracks) }
}
