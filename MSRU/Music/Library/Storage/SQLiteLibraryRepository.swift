//
//  SQLiteLibraryRepository.swift
//  MSRU
//
//  Canonical SQLite-backed user library repository replacing legacy Library.json.
//  Uses GRDB AppDatabase to persist saved tracks, playback sources, and favorites.
//

import Foundation
import AppFoundation
import GRDB

final class SQLiteLibraryRepository: LibraryRepository, Sendable {
    private let db: AppDatabase
    private let legacyFileURL: URL?

    init(db: AppDatabase = AppDatabase.shared, legacyFileURL: URL? = nil) {
        self.db = db
        self.legacyFileURL = legacyFileURL
    }

    // MARK: - Load

    func loadTracks() async throws -> [LibraryTrack] {
        try await migrateLegacyLibraryIfPresent()

        return try await db.reader.read { db in
            let trackRows = try Row.fetchAll(db, sql: "SELECT * FROM saved_library_tracks ORDER BY date_added DESC")
            guard !trackRows.isEmpty else { return [] }

            let sourceRows = try Row.fetchAll(db, sql: "SELECT * FROM saved_library_sources")
            var sourcesByTrackID: [String: [LibraryPlaybackSource]] = [:]

            for sRow in sourceRows {
                guard let trackID: String = sRow["library_track_id"],
                      let idStr: String = sRow["id"],
                      let id = UUID(uuidString: idStr),
                      let kindStr: String = sRow["kind"],
                      let kind = LibraryPlaybackSourceKind(rawValue: kindStr) else {
                    throw LibraryReadError.invalidSourceRow
                }

                let localPath: String? = sRow["local_url"]
                let localURL = localPath.flatMap { URL(fileURLWithPath: $0) }
                let remoteURLStr: String? = sRow["remote_url"]
                let remoteURL = remoteURLStr.flatMap { URL(string: $0) }
                let externalID: String? = sRow["external_id"]
                let title: String? = sRow["title"]
                let artist: String? = sRow["artist"]
                let duration: TimeInterval? = sRow["duration"]

                let source = LibraryPlaybackSource(
                    id: id,
                    kind: kind,
                    externalID: externalID,
                    localFileURL: localURL,
                    remoteURL: remoteURL
                )
                sourcesByTrackID[trackID, default: []].append(source)
            }

            var tracks: [LibraryTrack] = []
            for tRow in trackRows {
                guard let idStr: String = tRow["id"],
                      let id = UUID(uuidString: idStr),
                      let title: String = tRow["title"],
                      let artist: String = tRow["artist"],
                      let dateAdded: Date = tRow["date_added"] else {
                    throw LibraryReadError.invalidTrackRow
                }

                let album: String? = tRow["album"]
                let duration: TimeInterval = tRow["duration"] ?? 0
                let artworkReference: String? = tRow["artwork_reference"]
                let lastPlayedAt: Date? = tRow["last_played_at"]
                let sources = sourcesByTrackID[idStr] ?? []

                tracks.append(LibraryTrack(
                    id: id,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    artworkReference: artworkReference,
                    sources: sources,
                    dateAdded: dateAdded,
                    lastPlayedAt: lastPlayedAt
                ))
            }

            return tracks
        }
    }

    // MARK: - Save

    func saveTracks(_ tracks: [LibraryTrack]) async throws {
        let desiredIDs = Set(tracks.map { $0.id.uuidString })
        try await db.dbWriter.write { db in
            let existingIDs = try Set(String.fetchAll(db, sql: "SELECT id FROM saved_library_tracks"))
            for id in existingIDs.subtracting(desiredIDs) {
                try db.execute(sql: "DELETE FROM saved_library_tracks WHERE id = ?", arguments: [id])
            }
            for track in tracks {
                try Self.upsert(track, in: db)
            }
        }
    }

    func applyChanges(upserting tracks: [LibraryTrack], deleting ids: Set<UUID>) async throws {
        guard !tracks.isEmpty || !ids.isEmpty else { return }
        try await db.dbWriter.write { db in
            for id in ids {
                try db.execute(sql: "DELETE FROM saved_library_tracks WHERE id = ?", arguments: [id.uuidString])
            }
            for track in tracks {
                try Self.upsert(track, in: db)
            }
        }
    }

    nonisolated private static func upsert(_ track: LibraryTrack, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO saved_library_tracks (id, title, artist, album, duration, artwork_reference, date_added, last_played_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title, artist = excluded.artist, album = excluded.album,
                duration = excluded.duration, artwork_reference = excluded.artwork_reference,
                last_played_at = excluded.last_played_at
            """,
            arguments: [track.id.uuidString, track.title, track.artist, track.album,
                        track.duration ?? 0, track.artworkReference, track.dateAdded, track.lastPlayedAt]
        )
        let desiredSourceIDs = Set(track.sources.map { $0.id.uuidString })
        let existingSourceIDs = try Set(String.fetchAll(
            db, sql: "SELECT id FROM saved_library_sources WHERE library_track_id = ?",
            arguments: [track.id.uuidString]
        ))
        for id in existingSourceIDs.subtracting(desiredSourceIDs) {
            try db.execute(sql: "DELETE FROM saved_library_sources WHERE id = ?", arguments: [id])
        }
        for source in track.sources {
            try db.execute(
                sql: """
                INSERT INTO saved_library_sources (id, library_track_id, kind, local_url, remote_url, external_id)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    library_track_id = excluded.library_track_id, kind = excluded.kind,
                    local_url = excluded.local_url, remote_url = excluded.remote_url,
                    external_id = excluded.external_id
                """,
                arguments: [source.id.uuidString, track.id.uuidString, source.kind.rawValue,
                            source.localFileURL?.path, source.remoteURL?.absoluteString, source.externalID]
            )
        }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyLibraryIfPresent() async throws {
        guard let legacyURL = legacyFileURL ?? defaultLegacyLibraryURL(),
              FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        let data = try Data(contentsOf: legacyURL)

        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        let legacyTracks = (try? isoDecoder.decode([LibraryTrack].self, from: data))
            ?? (try? JSONDecoder().decode([LibraryTrack].self, from: data))
        guard let legacyTracks else {
            throw LibraryMigrationError.invalidLegacyFile(legacyURL)
        }

        try await db.dbWriter.write { db in
            for track in legacyTracks {
                let exists = try Int.fetchOne(
                    db, sql: "SELECT 1 FROM saved_library_tracks WHERE id = ?", arguments: [track.id.uuidString]
                ) != nil
                if exists {
                    let sourceIDs = try Set(String.fetchAll(
                        db, sql: "SELECT id FROM saved_library_sources WHERE library_track_id = ?",
                        arguments: [track.id.uuidString]
                    ))
                    guard Set(track.sources.map { $0.id.uuidString }).isSubset(of: sourceIDs) else {
                        throw LibraryMigrationError.conflictingSources(track.id)
                    }
                } else {
                    try Self.upsert(track, in: db)
                }
            }
            let persistedIDs = try Set(String.fetchAll(db, sql: "SELECT id FROM saved_library_tracks"))
            guard Set(legacyTracks.map { $0.id.uuidString }).isSubset(of: persistedIDs) else {
                throw LibraryMigrationError.verificationFailed
            }
        }

        let backupURL = legacyURL.appendingPathExtension("legacy.backup")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            guard try Data(contentsOf: backupURL) == data else {
                throw LibraryMigrationError.backupConflict(backupURL)
            }
            try FileManager.default.removeItem(at: legacyURL)
        } else {
            try FileManager.default.moveItem(at: legacyURL, to: backupURL)
        }
    }

    private func defaultLegacyLibraryURL() -> URL? {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appendingPathComponent("MSRU/Library.json")
    }
}

private enum LibraryMigrationError: LocalizedError {
    case invalidLegacyFile(URL)
    case conflictingSources(UUID)
    case verificationFailed
    case backupConflict(URL)

    var errorDescription: String? {
        switch self {
        case .invalidLegacyFile(let url): return "Library migration could not decode \(url.lastPathComponent); the original file was kept."
        case .conflictingSources(let id): return "Library migration found incomplete sources for \(id); the original file was kept."
        case .verificationFailed: return "Library migration verification failed; the original file was kept."
        case .backupConflict(let url): return "Library migration found a different backup at \(url.lastPathComponent); the original file was kept."
        }
    }
}

private enum LibraryReadError: LocalizedError {
    case invalidTrackRow
    case invalidSourceRow

    var errorDescription: String? {
        switch self {
        case .invalidTrackRow: return "A saved library row is invalid. Existing database data was kept."
        case .invalidSourceRow: return "A saved library source is invalid. Existing database data was kept."
        }
    }
}
