//
//  SubsonicLibrarySyncService.swift
//  MSRU
//
//  Bridges remote Subsonic items into MSRU's canonical SQLite catalog.
//  Maintains single source of truth across local and remote sources without duplicating models.
//

import Foundation
import AppFoundation
import MediaLibrary
import SubsonicKit
import GRDB

import CryptoKit
import MusicDomain

nonisolated public final class SubsonicLibrarySyncService: Sendable {
    public let serverID: LibrarySourceID
    public let client: SubsonicClient
    private let db: AppDatabase

    nonisolated public init(
        serverID: LibrarySourceID,
        client: SubsonicClient,
        db: AppDatabase = AppDatabase.shared
    ) {
        self.serverID = serverID
        self.client = client
        self.db = db
    }

    /// Full canonical ingestion of Subsonic songs into MSRU's SQLite database.
    /// Implements: DTO -> Domain -> Canonical Identity -> SQLite Catalog
    public func ingest(songs: [SubsonicSongDTO]) async throws {
        guard !songs.isEmpty else { return }

        let sourceRepo = SourceRepository(db: db)
        let identityRepo = IdentityRepository(db: db)
        let assetRepo = AssetRepository(db: db)
        let sourceID = SourceID("src_\(serverID.rawValue)")

        // 1. Ensure remote Source is registered in SQLite
        let remoteSource = Source(
            id: sourceID,
            sourceType: .futureProvider,
            uri: client.baseURL.absoluteString,
            displayName: "Subsonic (\(client.username))",
            capabilities: [.supportsStreaming, .supportsArtwork, .supportsStableExternalID],
            isEnabled: true,
            lastReconciledAt: Date()
        )
        try? await sourceRepo.insertOrUpdate(remoteSource)

        // 2. Group songs by album title to determine stable primary album artist
        var songsByAlbum: [String: [SubsonicSongDTO]] = [:]
        for song in songs {
            let albumTitle = song.album?.trimmingCharacters(in: .whitespacesAndNewlines)
            let alb = (albumTitle?.isEmpty == false) ? albumTitle! : "Unknown Album"
            songsByAlbum[alb, default: []].append(song)
        }

        var primaryArtistByAlbum: [String: String] = [:]
        for (alb, songList) in songsByAlbum {
            let counts = songList.reduce(into: [String: Int]()) { acc, s in
                let art = s.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Artist"
                acc[art, default: 0] += 1
            }
            let candidate = counts.max(by: { $0.value < $1.value })?.key ?? songList.first?.artist ?? "Unknown Artist"
            let primary = candidate.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? candidate
            primaryArtistByAlbum[alb] = primary.isEmpty ? candidate : primary
        }

        var artists: [(id: ArtistID, name: String)] = []
        var recordings: [(id: RecordingID, title: String, duration: Double?)] = []
        var releaseGroups: [(id: ReleaseGroupID, title: String)] = []
        var releases: [(id: ReleaseID, releaseGroupID: ReleaseGroupID?, title: String, year: Int?, artworkAssetID: String?)] = []
        var releaseTracks: [(id: ReleaseTrackID, releaseID: ReleaseID, trackNumber: Int, title: String, duration: Double?, recordingID: RecordingID)] = []
        var artistCredits: [(artistID: ArtistID, entityType: String, entityID: String)] = []
        var assets: [PersistedAssetRecord] = []
        var streamAssets: [AssetRepository.PersistedStreamAssetRecord] = []

        for song in songs {
            let trackTitle = song.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trackArtist = song.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Artist"
            let albumTitle = song.album?.trimmingCharacters(in: .whitespacesAndNewlines)
            let relTitle = (albumTitle?.isEmpty == false) ? albumTitle! : "Unknown Album"
            let albumArtist = primaryArtistByAlbum[relTitle] ?? trackArtist

            // Source-scoped entity identity generation strictly separating source asset from canonical identity
            let recID = DeterministicID.sourceRecording(sourceID: sourceID, itemID: song.id)
            let trackArtID = DeterministicID.sourceArtist(sourceID: sourceID, itemID: song.artistId ?? trackArtist)
            let albumArtID = DeterministicID.sourceArtist(sourceID: sourceID, itemID: song.albumId ?? albumArtist)
            let rgID = DeterministicID.sourceReleaseGroup(sourceID: sourceID, itemID: song.albumId ?? relTitle)
            let relID = DeterministicID.sourceRelease(sourceID: sourceID, itemID: song.albumId ?? relTitle)
            let trkID = DeterministicID.releaseTrack(releaseID: relID, medium: song.discNumber ?? 1, track: song.track ?? 1)
            let relPath = song.id
            let astID = DeterministicID.asset(sourceID: sourceID, relativePath: relPath)

            artists.append((id: trackArtID, name: trackArtist))
            if trackArtID != albumArtID {
                artists.append((id: albumArtID, name: albumArtist))
            }

            let duration = song.duration.map { Double($0) }
            recordings.append((id: recID, title: trackTitle, duration: duration))
            releaseGroups.append((id: rgID, title: relTitle))

            let artRef = song.coverArt.map { "subsonic:\(serverID.rawValue):\($0)" }
            releases.append((id: relID, releaseGroupID: rgID, title: relTitle, year: song.year, artworkAssetID: artRef))
            releaseTracks.append((id: trkID, releaseID: relID, trackNumber: song.track ?? 1, title: trackTitle, duration: duration, recordingID: recID))
            artistCredits.append((artistID: trackArtID, entityType: "recording", entityID: recID.rawValue))
            artistCredits.append((artistID: albumArtID, entityType: "release", entityID: relID.rawValue))

            assets.append(PersistedAssetRecord(
                id: astID,
                sourceID: sourceID,
                relativePath: relPath,
                fileSize: Int64(song.size ?? 0),
                mtime: Date().timeIntervalSince1970,
                format: song.suffix?.uppercased() ?? "MP3",
                bitrateKbps: song.bitRate,
                duration: duration ?? 0,
                recordingID: recID
            ))

            streamAssets.append(AssetRepository.PersistedStreamAssetRecord(
                assetID: astID,
                providerID: "subsonic",
                remoteItemID: song.id,
                streamURL: nil,
                isHLS: false,
                expiresAt: nil
            ))
        }

        // 3. Batch commit into canonical SQLite tables and multi-lingual FTS5 index
        try await identityRepo.batchUpsertEntities(
            artists: artists,
            recordings: recordings,
            releaseGroups: releaseGroups,
            releases: releases,
            releaseTracks: releaseTracks,
            artistCredits: artistCredits
        )
        try await assetRepo.batchUpsert(assets)
        try await assetRepo.batchUpsertStreamAssets(streamAssets)
    }

    /// Synchronizes recent and alphabetical albums and playlists from remote Subsonic server into local SQLite.
    public func sync(batchSize: Int = 100) async throws {
        let albums = try await client.albumList2(type: "alphabeticalByArtist", size: batchSize, offset: 0)
        var allSongs: [SubsonicSongDTO] = []

        for album in albums {
            if let detailed = try? await client.album(id: album.id), let songs = detailed.song {
                allSongs.append(contentsOf: songs)
            }
        }

        try await ingest(songs: allSongs)

        // 4. Synchronize remote playlists
        await syncPlaylists()
    }

    /// Synchronizes remote Subsonic playlists into local SQLite playlists table.
    public func syncPlaylists() async {
        do {
            let playlists = try await client.playlists()
            guard !playlists.isEmpty else { return }

            let sourceID = SourceID("src_\(serverID.rawValue)")
            for pl in playlists {
                let detailed = (try? await client.playlist(id: pl.id)) ?? pl
                let songIDs = detailed.entry?.map(\.id) ?? []

                let key = "\(sourceID.rawValue):playlist:\(pl.id)"
                let digest = SHA256.hash(data: Data(key.utf8))
                var bytes = Array(digest.prefix(16))
                bytes[6] = (bytes[6] & 0x0F) | 0x40
                bytes[8] = (bytes[8] & 0x3F) | 0x80
                let uuid = UUID(uuid: (
                    bytes[0], bytes[1], bytes[2], bytes[3],
                    bytes[4], bytes[5], bytes[6], bytes[7],
                    bytes[8], bytes[9], bytes[10], bytes[11],
                    bytes[12], bytes[13], bytes[14], bytes[15]
                ))

                let serverName = client.username.isEmpty ? "Subsonic" : "\(client.username)@Subsonic"
                let desc = pl.comment?.isEmpty == false ? pl.comment! : "来自 \(serverName)"

                try await db.dbWriter.write { db in
                    try db.execute(
                        sql: """
                        INSERT INTO playlists (id, title, description, artwork_reference, is_pinned, created_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            title = excluded.title,
                            description = excluded.description,
                            updated_at = excluded.updated_at
                        """,
                        arguments: [
                            uuid.uuidString,
                            pl.name,
                            desc,
                            nil,
                            0,
                            Date(),
                            Date()
                        ]
                    )

                    try db.execute(sql: "DELETE FROM playlist_tracks WHERE playlist_id = ?", arguments: [uuid.uuidString])

                    for (pos, trackID) in songIDs.enumerated() {
                        try db.execute(
                            sql: """
                            INSERT INTO playlist_tracks (playlist_id, track_id, position, added_at)
                            VALUES (?, ?, ?, ?)
                            """,
                            arguments: [
                                uuid.uuidString,
                                trackID,
                                pos,
                                Date()
                            ]
                        )
                    }
                }
            }
        } catch {
            print("[SubsonicLibrarySyncService] Failed to sync playlists: \(error)")
        }
    }
}
