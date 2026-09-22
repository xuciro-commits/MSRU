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
        await migrateLegacyLibraryIfPresent()

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
                    continue
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
                    continue
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
        try await db.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM saved_library_tracks")

            for track in tracks {
                try db.execute(
                    sql: """
                    INSERT INTO saved_library_tracks (id, title, artist, album, duration, artwork_reference, date_added, last_played_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        track.id.uuidString,
                        track.title,
                        track.artist,
                        track.album,
                        track.duration,
                        track.artworkReference,
                        track.dateAdded,
                        track.lastPlayedAt
                    ]
                )

                for source in track.sources {
                    try db.execute(
                        sql: """
                        INSERT INTO saved_library_sources (id, library_track_id, kind, local_url, remote_url, external_id, title, artist, duration)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            source.id.uuidString,
                            track.id.uuidString,
                            source.kind.rawValue,
                            source.localFileURL?.path,
                            source.remoteURL?.absoluteString,
                            source.externalID,
                            nil,
                            nil,
                            nil
                        ]
                    )
                }
            }
        }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyLibraryIfPresent() async {
        guard let legacyURL = legacyFileURL ?? defaultLegacyLibraryURL(),
              FileManager.default.fileExists(atPath: legacyURL.path),
              let data = try? Data(contentsOf: legacyURL),
              !data.isEmpty else {
            return
        }

        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        let legacyTracks = (try? isoDecoder.decode([LibraryTrack].self, from: data))
            ?? (try? JSONDecoder().decode([LibraryTrack].self, from: data))
        if let legacyTracks, !legacyTracks.isEmpty {
            try? await saveTracks(legacyTracks)
        }

        try? FileManager.default.removeItem(at: legacyURL)
    }

    private func defaultLegacyLibraryURL() -> URL? {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appendingPathComponent("MSRU/Library.json")
    }
}
