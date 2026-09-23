//
//  WebLibraryStore.swift
//  MSRU
//
//  Library membership for tracks from web catalogues (Openverse). They live
//  in the same index as files and servers, under the `src_openverse` source.
//

import Foundation
import Observation
import AppFoundation
import GRDB
import MusicDomain

/// A web catalogue track as stored in the library index.
nonisolated public struct WebTrack: Sendable, Hashable {
    public let itemID: String
    public let title: String
    public let artist: String?
    public let duration: TimeInterval?
    public let streamURL: String
    public let thumbnailURL: String?

    public init(itemID: String, title: String, artist: String?, duration: TimeInterval?,
                streamURL: String, thumbnailURL: String?) {
        self.itemID = itemID
        self.title = title
        self.artist = artist
        self.duration = duration
        self.streamURL = streamURL
        self.thumbnailURL = thumbnailURL
    }

    public init(openverse audio: OpenverseAudio) {
        self.init(itemID: audio.id, title: audio.title, artist: audio.creator,
                  duration: audio.durationMilliseconds.map { Double($0) / 1000 },
                  streamURL: audio.mediaURLString, thumbnailURL: audio.thumbnailURLString)
    }
}

/// Index operations for web tracks; synchronous so migrations can use them.
nonisolated public enum WebLibraryIndex {
    public static let sourceID = SourceID("src_openverse")

    public static func assetID(itemID: String) -> AssetID {
        DeterministicID.asset(sourceID: sourceID, relativePath: itemID)
    }

    public static func ingest(_ track: WebTrack, dateAdded: Date = Date(), in db: Database) throws {
        let now = Date()
        try db.execute(sql: """
            INSERT OR IGNORE INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, last_reconciled_at, created_at, updated_at)
            VALUES (?, ?, 'https://api.openverse.org', 'Openverse', ?, 1, ?, ?, ?)
            """, arguments: [sourceID.rawValue, SourceType.futureProvider.rawValue,
                             SourceCapabilities([.supportsStreaming, .supportsArtwork, .supportsStableExternalID]).rawValue,
                             now, now, now])

        let artist = (track.artist?.isEmpty == false) ? track.artist! : "Unknown Artist"
        let recordingID = DeterministicID.sourceRecording(sourceID: sourceID, itemID: track.itemID)
        let artistID = DeterministicID.sourceArtist(sourceID: sourceID, itemID: artist)
        let releaseTitle = "Openverse Single"
        let releaseID = DeterministicID.sourceRelease(sourceID: sourceID, itemID: releaseTitle)
        let releaseGroupID = DeterministicID.sourceReleaseGroup(sourceID: sourceID, itemID: releaseTitle)
        let releaseTrackID = DeterministicID.releaseTrack(releaseID: releaseID, medium: 1, track: 1)
        try IdentityRepository.batchUpsertEntities(
            artists: [(id: artistID, name: artist)],
            recordings: [(id: recordingID, title: track.title, duration: track.duration)],
            releaseGroups: [(id: releaseGroupID, title: releaseTitle)],
            releases: [(id: releaseID, releaseGroupID: releaseGroupID, title: releaseTitle, year: nil, artworkAssetID: track.thumbnailURL)],
            releaseTracks: [(id: releaseTrackID, releaseID: releaseID, trackNumber: 1, title: track.title, duration: track.duration, recordingID: recordingID)],
            artistCredits: [
                (artistID: artistID, entityType: "recording", entityID: recordingID.rawValue),
                (artistID: artistID, entityType: "release", entityID: releaseID.rawValue)
            ],
            in: db
        )

        let assetID = assetID(itemID: track.itemID)
        try AssetRepository.batchUpsert([PersistedAssetRecord(
            id: assetID, sourceID: sourceID, relativePath: track.itemID, fileSize: 0,
            mtime: now.timeIntervalSince1970, format: "MP3", bitrateKbps: 128,
            duration: track.duration ?? 0, recordingID: recordingID
        )], in: db)
        try AssetRepository.batchUpsertStreamAssets([AssetRepository.PersistedStreamAssetRecord(
            assetID: assetID, providerID: "openverse", remoteItemID: track.itemID,
            streamURL: track.streamURL, isHLS: false, expiresAt: nil
        )], in: db)
        try db.execute(sql: """
            INSERT OR IGNORE INTO library_entries (id, recording_id, is_favorite, date_added)
            VALUES (?, ?, 0, ?)
            """, arguments: [DeterministicID.libraryEntry(recordingID: recordingID).rawValue, recordingID.rawValue, dateAdded])
    }

    public static func remove(itemID: String, in db: Database) throws {
        try AssetRepository.deleteAssets([assetID(itemID: itemID).rawValue], in: db)
    }

    /// Web tracks in the Library, newest first, keyed by their catalogue item ID.
    public static func fetchTracks(in db: Database) throws -> [(itemID: String, track: LocalTrack)] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT a.relative_path AS item_id, sa.stream_url, r.title, r.duration,
                   (SELECT art.name FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id
                    WHERE ac.entity_type = 'recording' AND ac.entity_id = r.id
                    ORDER BY ac.position LIMIT 1) AS artist,
                   (SELECT rel.artwork_asset_id FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                    WHERE rt.recording_id = r.id LIMIT 1) AS artwork
            FROM assets a
            JOIN stream_assets sa ON sa.asset_id = a.id
            JOIN recordings r ON r.id = a.recording_id
            LEFT JOIN library_entries le ON le.recording_id = r.id
            WHERE a.source_id = ?
            ORDER BY le.date_added DESC, r.sort_title ASC
            """, arguments: [sourceID.rawValue])
        return rows.compactMap { row in
            guard let itemID: String = row["item_id"],
                  let stream: String = row["stream_url"], let url = URL(string: stream) else { return nil }
            return (itemID, LocalTrack(fileURL: url, title: row["title"] ?? itemID,
                                       artist: row["artist"] ?? "Unknown Artist",
                                       duration: row["duration"] ?? 0, artworkReference: row["artwork"]))
        }
    }
}

/// Observable membership of web tracks, shared by Browse and the Library.
@MainActor
@Observable
public final class WebLibraryStore {
    public private(set) var tracks: [LocalTrack] = []
    public private(set) var errorMessage: String?
    private var itemIDs: [String: String] = [:]   // track ID → catalogue item ID
    private let db: AppDatabase

    public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    public func load() async {
        do {
            let loaded = try await db.reader.read { try WebLibraryIndex.fetchTracks(in: $0) }
            tracks = loaded.map(\.track)
            itemIDs = Dictionary(loaded.map { ($0.track.id, $0.itemID) }, uniquingKeysWith: { first, _ in first })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func contains(openverseID: String) -> Bool {
        itemIDs.values.contains(openverseID)
    }

    public func add(openverse audio: OpenverseAudio) async {
        await mutate { try WebLibraryIndex.ingest(WebTrack(openverse: audio), in: $0) }
    }

    public func remove(openverseID: String) async {
        await mutate { try WebLibraryIndex.remove(itemID: openverseID, in: $0) }
    }

    public func remove(trackIDs: Set<String>) async {
        let targets = trackIDs.compactMap { itemIDs[$0] }
        guard !targets.isEmpty else { return }
        await mutate { db in
            for itemID in targets { try WebLibraryIndex.remove(itemID: itemID, in: db) }
        }
    }

    private func mutate(_ change: @escaping @Sendable (Database) throws -> Void) async {
        do {
            try await db.dbWriter.write(change)
        } catch {
            errorMessage = error.localizedDescription
        }
        await load()
    }
}
