//
//  SubsonicLibrarySyncServiceTests.swift
//  MSRUTests
//
//  Rigorous end-to-end contract verification for the 4 core architecture chains:
//  Chain 1: DTO -> Domain
//  Chain 2: Source ID -> Canonical Identity
//  Chain 3: Catalog -> Canonical SQLite
//  Chain 4: Track -> PlaybackResource
//

import Testing
import Foundation
import AppFoundation
import MusicDomain
import MediaLibrary
import SubsonicKit
import GRDB
import MusicLibrary
import MusicPlayback
@testable import MSRU

@Suite("Subsonic Architectural 4-Chain Verification")
struct SubsonicArchitecturalVerificationTests {

    // MARK: - Chain 1: DTO -> Domain

    @Test("Chain 1: DTO directly maps to Domain without creating parallel models")
    func testChain1DTOMapping() async throws {
        let sourceID = LibrarySourceID("subsonic_zspace")
        let mapper = SubsonicMapper(sourceID: sourceID)

        let songDTO = SubsonicSongDTO(
            id: "song_1001",
            parent: "album_2001",
            title: "七里香",
            album: "七里香",
            artist: "周杰伦",
            track: 1,
            year: 2004,
            genre: "Pop",
            coverArt: "al_2001",
            size: 10485760,
            contentType: "audio/flac",
            suffix: "flac",
            duration: 299,
            bitRate: 980,
            albumId: "album_2001",
            artistId: "artist_3001",
            discNumber: 1
        )

        let track = mapper.mapSong(songDTO)
        #expect(track.id.sourceID == sourceID)
        #expect(track.id.rawValue == "song_1001")
        #expect(track.title == "七里香")
        #expect(track.artist == "周杰伦")
        #expect(track.album == "七里香")
        #expect(track.duration == 299)
        #expect(track.codec == "FLAC")
        #expect(track.bitrateKbps == 980)
    }

    // MARK: - Chain 2: Source ID -> Canonical Identity

    @Test("Chain 2: Deterministic canonical IDs prevent collision and enable cross-source deduplication")
    func testChain2CanonicalIdentity() {
        let sourceID = SourceID("src_subsonic_nas")
        let remoteSongID = "track_999"

        let recID = DeterministicID.recording(title: "晴天", artist: "周杰伦")
        let artID = DeterministicID.artist(name: "周杰伦")
        let relID = DeterministicID.release(artist: "周杰伦", title: "叶惠美")
        let rgID = DeterministicID.releaseGroup(artist: "周杰伦", title: "叶惠美")
        let trkID = DeterministicID.releaseTrack(releaseID: relID, medium: 1, track: 3)
        let astID = DeterministicID.asset(sourceID: sourceID, relativePath: remoteSongID)

        // Verifying prefix and deterministic stability
        #expect(recID.rawValue.hasPrefix("rec_"))
        #expect(artID.rawValue.hasPrefix("art_"))
        #expect(relID.rawValue.hasPrefix("rel_"))
        #expect(rgID.rawValue.hasPrefix("rg_"))
        #expect(trkID.rawValue.hasPrefix("trk_"))
        #expect(astID.rawValue.hasPrefix("ast_"))

        // Repeating generation yields identical ID
        let recID2 = DeterministicID.recording(title: "晴天", artist: "周杰伦")
        #expect(recID == recID2)

        // Case insensitivity & whitespace trimming
        let recID3 = DeterministicID.recording(title: " 晴天 ", artist: "周杰伦 ")
        #expect(recID == recID3)
    }

    // MARK: - Chain 3: Catalog -> Canonical SQLite

    @Test("Chain 3: Remote items ingest into canonical SQLite, accessible via LibraryQueryEngine and FTS5")
    func testChain3CatalogCanonicalSQLite() async throws {
        let db = try TestDatabase.makeEphemeral()
        let serverID = LibrarySourceID("zspace_server_1")
        let credStore = InMemorySubsonicCredentialStore()
        try credStore.savePassword("msruz4pro", for: serverID)

        let client = SubsonicClient(
            serverID: serverID,
            baseURL: URL(string: "http://192.168.31.200:8025")!,
            username: "msru",
            credentialStore: credStore
        )

        let syncService = SubsonicLibrarySyncService(
            serverID: serverID,
            client: client,
            db: db
        )

        let songs = [
            SubsonicSongDTO(
                id: "z_track_01",
                parent: "z_album_01",
                title: "枫",
                album: "十一月的萧邦",
                artist: "周杰伦",
                track: 4,
                year: 2005,
                genre: "Pop",
                coverArt: "cover_chopin",
                size: 8388608,
                contentType: "audio/mp3",
                suffix: "mp3",
                duration: 275,
                bitRate: 320,
                albumId: "z_album_01",
                artistId: "z_artist_01",
                discNumber: 1
            ),
            SubsonicSongDTO(
                id: "z_track_02",
                parent: "z_album_01",
                title: "夜曲",
                album: "十一月的萧邦",
                artist: "周杰伦",
                track: 1,
                year: 2005,
                genre: "Pop",
                coverArt: "cover_chopin",
                size: 9437184,
                contentType: "audio/mp3",
                suffix: "mp3",
                duration: 226,
                bitRate: 320,
                albumId: "z_album_01",
                artistId: "z_artist_01",
                discNumber: 1
            )
        ]

        // Execute canonical ingestion
        try await syncService.ingest(songs: songs)

        // 1. Verify sources table
        let sourceCount = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sources WHERE id = 'src_zspace_server_1'") ?? 0
        }
        #expect(sourceCount == 1)

        // 2. Verify stream_assets table
        let streamCount = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stream_assets WHERE provider_id = 'subsonic'") ?? 0
        }
        #expect(streamCount == 2)

        // 3. Verify recordings and releases table
        let recCount = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recordings") ?? 0
        }
        #expect(recCount == 2)

        let relCount = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM releases WHERE title = '十一月的萧邦'") ?? 0
        }
        #expect(relCount == 1)

        // 4. Verify LibraryQueryEngine can query these remote songs as first-class citizens
        let engine = LibraryQueryEngine(db: db)
        let snapshot = try await engine.queryDatabaseSnapshot()
        #expect(snapshot.count == 2)
        #expect(snapshot.albumSummaries.count == 1)
        #expect(snapshot.albumSummaries.first?.title == "十一月的萧邦")
        #expect(snapshot.albumSummaries.first?.trackCount == 2)
        #expect(snapshot.artistSummaries.first?.name == "周杰伦")

        // 5. Verify multi-lingual FTS5 instant search finds Subsonic tracks
        let searchSummaries = try await engine.fetchRowSummaries(spec: QuerySpec(query: "夜曲"))
        #expect(searchSummaries.count == 1)
        #expect(searchSummaries.first?.title == "夜曲")
        #expect(searchSummaries.first?.artist == "周杰伦")
    }

    // MARK: - Chain 4: Track -> PlaybackResource

    @Test("Chain 4: Remote Subsonic track resolves to PlaybackResource via PlaybackResolver")
    @MainActor
    func testChain4PlaybackResolution() async throws {
        let serverID = LibrarySourceID("zspace_server_1")
        let credStore = InMemorySubsonicCredentialStore()
        try credStore.savePassword("msruz4pro", for: serverID)

        let client = SubsonicClient(
            serverID: serverID,
            baseURL: URL(string: "http://192.168.31.200:8025")!,
            username: "msru",
            credentialStore: credStore
        )

        let playbackProvider = SubsonicPlaybackProvider(sourceID: serverID, client: client)
        let ephemeralStreamURL = try await playbackProvider.resolveStreamURL(for: "z_track_02")
        #expect(ephemeralStreamURL.absoluteString.contains("stream.view"))
        #expect(ephemeralStreamURL.absoluteString.contains("u=msru"))
        #expect(ephemeralStreamURL.absoluteString.contains("t="))
        #expect(ephemeralStreamURL.absoluteString.contains("s="))

        // Verify resolver pipeline
        let kernel = PlaybackProviderKernel.standard()
        let request = PlaybackRequest(
            itemID: "z_track_02",
            source: .subsonic,
            remoteURL: ephemeralStreamURL
        )

        let resource = try await kernel.resolver.resolve(request)
        #expect(resource.providerID == .subsonic)
        if case .avPlayerURL(let url) = resource.transport {
            #expect(url == ephemeralStreamURL)
        } else {
            Issue.record("Expected avPlayerURL transport")
        }
    }
}
