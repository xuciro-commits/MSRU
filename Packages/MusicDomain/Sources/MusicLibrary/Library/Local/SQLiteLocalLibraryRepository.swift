//
//  SQLiteLocalLibraryRepository.swift
//  MSRU
//
//  Canonical SQLite-backed local library repository replacing legacy JSON manifests.
//  Directly queries and mutates GRDB AppDatabase for sub-millisecond execution.
//

import Foundation
import AVFoundation
import AppFoundation
import GRDB
import MusicDomain

public actor SQLiteLocalLibraryRepository: LocalLibraryRepository {
    private let db: AppDatabase
    private let directory: URL?

    public init(db: AppDatabase = AppDatabase.shared, directory: URL? = nil) {
        self.db = db
        self.directory = directory
    }

    // MARK: - Load

    public func loadTracks() async throws -> [LocalTrack] {
        // One-time automatic migration of legacy external_tracks.json if present
        try await migrateLegacyManifestIfPresent()

        let baseMediaDir = try? self.mediaDirectory()

        return try await db.reader.read { db in
            let sql = """
            SELECT
                a.id as asset_id,
                a.relative_path,
                fa.bookmark_blob,
                rec.id as recording_id,
                rec.title as track_title,
                rec.duration,
                art.name as artist_name,
                rel.title as album_title,
                rel.release_year,
                rel.artwork_asset_id,
                rt.track_number
            FROM assets a
            JOIN sources s ON s.id = a.source_id
            LEFT JOIN file_assets fa ON fa.asset_id = a.id
            LEFT JOIN recordings rec ON rec.id = a.recording_id
            LEFT JOIN release_tracks rt ON rt.recording_id = rec.id
            LEFT JOIN releases rel ON rel.id = rt.release_id
            LEFT JOIN artist_credits ac ON ac.entity_id = rec.id AND ac.entity_type = 'recording'
            LEFT JOIN artists art ON art.id = ac.artist_id
            WHERE s.source_type IN ('local_folder', 'localFolder')
            ORDER BY rec.sort_title ASC, a.relative_path ASC
            """

            let rows = try Row.fetchAll(db, sql: sql)
            var tracks: [LocalTrack] = []
            var seenPaths = Set<String>()

            for row in rows {
                guard let relativePath: String = row["relative_path"] else { continue }
                if !seenPaths.insert(relativePath).inserted {
                    continue
                }

                let fileURL: URL
                if relativePath.hasPrefix("/") {
                    fileURL = URL(fileURLWithPath: relativePath)
                } else if let base = baseMediaDir {
                    fileURL = base.appendingPathComponent(relativePath)
                } else {
                    fileURL = URL(fileURLWithPath: relativePath)
                }

                let title: String = row["track_title"] ?? fileURL.deletingPathExtension().lastPathComponent
                let artist: String = row["artist_name"] ?? "Unknown Artist"
                let album: String? = row["album_title"]
                let duration: Double = row["duration"] ?? 0
                let artworkRef: String? = row["artwork_asset_id"]
                let year: Int? = row["release_year"]

                var trackNumber: Int? = nil
                if let rawTrk: String = row["track_number"] {
                    let digits = rawTrk.prefix(while: { $0.isNumber })
                    if let num = Int(digits) {
                        trackNumber = num
                    }
                }

                tracks.append(LocalTrack(
                    fileURL: fileURL,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    artworkReference: artworkRef,
                    artworkData: nil,
                    trackNumber: trackNumber,
                    year: year
                ))
            }

            return tracks
        }
    }

    public func fetchPage(_ request: LocalTrackPageRequest) async throws -> LocalTrackPage {
        try await migrateLegacyManifestIfPresent()
        let mediaDir = try? mediaDirectory()
        let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortColumn: String
        switch request.sort {
        case .dateAdded: sortColumn = "created_at"
        case .title: sortColumn = "track_title"
        case .artist: sortColumn = "artist_name"
        case .album: sortColumn = "album_title"
        case .duration: sortColumn = "duration"
        }
        let direction = request.ascending ? "ASC" : "DESC"
        return try await db.reader.read { db in
            let projection = """
                WITH local_tracks AS (
                    SELECT a.id AS asset_id, a.relative_path, a.created_at,
                           COALESCE(r.title, a.relative_path) AS track_title,
                           COALESCE(r.duration, a.duration, 0) AS duration,
                           COALESCE((SELECT art.name FROM artist_credits ac
                                     JOIN artists art ON art.id = ac.artist_id
                                     WHERE ac.entity_id = r.id AND ac.entity_type = 'recording'
                                     ORDER BY ac.position LIMIT 1), 'Unknown Artist') AS artist_name,
                           (SELECT rel.title FROM release_tracks rt
                            JOIN releases rel ON rel.id = rt.release_id
                            WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS album_title,
                           (SELECT rel.release_year FROM release_tracks rt
                            JOIN releases rel ON rel.id = rt.release_id
                            WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS release_year,
                           (SELECT rel.artwork_asset_id FROM release_tracks rt
                            JOIN releases rel ON rel.id = rt.release_id
                            WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS artwork_asset_id,
                           (SELECT rt.track_number FROM release_tracks rt
                            WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS track_number
                    FROM assets a JOIN sources s ON s.id = a.source_id
                    LEFT JOIN recordings r ON r.id = a.recording_id
                    WHERE s.source_type IN ('local_folder', 'localFolder')
                )
                """
            let filter = query.isEmpty ? "" : " WHERE instr(lower(track_title), lower(?)) > 0 OR instr(lower(artist_name), lower(?)) > 0 OR instr(lower(COALESCE(album_title, '')), lower(?)) > 0"
            let filterArgs: StatementArguments = query.isEmpty ? [] : [query, query, query]
            let totalCount = try Int.fetchOne(db, sql: projection + " SELECT COUNT(*) FROM local_tracks" + filter,
                                              arguments: filterArgs) ?? 0
            let rows = try Row.fetchAll(db, sql: projection + " SELECT * FROM local_tracks" + filter +
                " ORDER BY \(sortColumn) \(direction), asset_id ASC LIMIT ? OFFSET ?",
                arguments: filterArgs + [request.limit, request.offset])
            let tracks = rows.compactMap { row -> LocalTrack? in
                guard let path: String = row["relative_path"] else { return nil }
                let url = path.hasPrefix("/") ? URL(fileURLWithPath: path)
                    : (mediaDir?.appendingPathComponent(path) ?? URL(fileURLWithPath: path))
                let rawNumber: String? = row["track_number"]
                let number = rawNumber.flatMap { Int($0.prefix(while: { $0.isNumber })) }
                return LocalTrack(fileURL: url,
                                  title: row["track_title"] ?? url.deletingPathExtension().lastPathComponent,
                                  artist: row["artist_name"] ?? "Unknown Artist",
                                  album: row["album_title"], duration: row["duration"] ?? 0,
                                  artworkReference: row["artwork_asset_id"],
                                  trackNumber: number, year: row["release_year"])
            }
            return LocalTrackPage(tracks: tracks, totalCount: totalCount, offset: request.offset)
        }
    }

    public func fetchTracks(withIDs ids: Set<String>) async throws -> [LocalTrack] {
        guard !ids.isEmpty else { return [] }
        let paths = Set(ids.map { id in
            if let url = URL(string: id), url.isFileURL { return url.standardizedFileURL.path }
            return URL(fileURLWithPath: id).standardizedFileURL.path
        })
        let orderedPaths = paths.sorted()
        var tracks: [LocalTrack] = []
        for start in stride(from: 0, to: orderedPaths.count, by: 500) {
            let batch = Array(orderedPaths[start..<min(start + 500, orderedPaths.count)])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
            tracks.append(contentsOf: try await fetchLocalTracks(
                predicate: "a.relative_path IN (\(placeholders))",
                arguments: batch
            ))
        }
        return tracks
    }

    public func fetchTracks(forReleaseIDs ids: Set<String>) async throws -> [LocalTrack] {
        guard !ids.isEmpty else { return [] }
        let values = ids.sorted()
        var tracks: [LocalTrack] = []
        for start in stride(from: 0, to: values.count, by: 500) {
            let batch = Array(values[start..<min(start + 500, values.count)])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
            tracks.append(contentsOf: try await fetchLocalTracks(
                predicate: """
                    EXISTS (SELECT 1 FROM release_tracks selected
                            WHERE selected.recording_id = r.id
                              AND selected.release_id IN (\(placeholders)))
                    """,
                arguments: batch
            ))
        }
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }

    public func fetchTracks(forArtistIDs ids: Set<String>) async throws -> [LocalTrack] {
        guard !ids.isEmpty else { return [] }
        let values = ids.sorted()
        var tracks: [LocalTrack] = []
        for start in stride(from: 0, to: values.count, by: 500) {
            let batch = Array(values[start..<min(start + 500, values.count)])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
            tracks.append(contentsOf: try await fetchLocalTracks(
                predicate: """
                    EXISTS (SELECT 1 FROM artist_credits selected
                            WHERE selected.entity_type = 'recording'
                              AND selected.entity_id = r.id
                              AND selected.artist_id IN (\(placeholders)))
                    """,
                arguments: batch
            ))
        }
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }

    public func fetchTracks(inFolder folder: URL) async throws -> [LocalTrack] {
        let path = folder.standardizedFileURL.path
        let childPrefix = path.hasSuffix("/") ? path : path + "/"
        return try await fetchLocalTracks(
            predicate: "a.relative_path = ? OR substr(a.relative_path, 1, length(?)) = ?",
            arguments: [path, childPrefix, childPrefix]
        )
    }

    public func fetchTracks(withFilenames names: Set<String>) async throws -> [LocalTrack] {
        guard !names.isEmpty else { return [] }
        var tracks: [LocalTrack] = []
        for name in names.sorted() {
            tracks.append(contentsOf: try await fetchLocalTracks(
                predicate: "a.relative_path = ? OR (substr(a.relative_path, -length(?)) = ? AND substr(a.relative_path, -length(?) - 1, 1) = '/')",
                arguments: [name, name, name, name]
            ))
        }
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }

    public func fetchTracks(matchingAlbum title: String, artist: String) async throws -> [LocalTrack] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return [] }
        let candidates = try await fetchLocalTracks(
            predicate: """
                EXISTS (SELECT 1 FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                        WHERE rt.recording_id = r.id AND lower(trim(rel.title)) = lower(?))
                """,
            arguments: [cleanTitle]
        )
        return candidates.filter {
            cleanArtist.isEmpty || $0.artist.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(cleanArtist) == .orderedSame
        }
    }

    public func fetchTracks(matchingArtist name: String) async throws -> [LocalTrack] {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return [] }
        let candidates = try await fetchLocalTracks(
            predicate: """
                EXISTS (SELECT 1 FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id
                        WHERE ac.entity_type = 'recording' AND ac.entity_id = r.id
                          AND instr(lower(art.name), lower(?)) > 0)
                """,
            arguments: [cleanName]
        )
        return candidates.filter { ArtistCreditCleaner.containsArtist(cleanName, in: $0.artist) }
    }

    public func fetchMaintenancePage(afterPath: String?, limit: Int) async throws -> LocalMaintenancePage {
        try await migrateLegacyManifestIfPresent()
        let paths = try await db.reader.read { db in
            try String.fetchAll(db, sql: """
                SELECT a.relative_path FROM assets a JOIN sources s ON s.id = a.source_id
                WHERE s.source_type IN ('local_folder', 'localFolder')
                  AND (? IS NULL OR a.relative_path > ?)
                ORDER BY a.relative_path LIMIT ?
                """, arguments: [afterPath, afterPath, max(1, min(limit, 512))])
        }
        guard !paths.isEmpty else { return LocalMaintenancePage(tracks: [], nextPath: nil) }
        let placeholders = Array(repeating: "?", count: paths.count).joined(separator: ",")
        let tracks = try await fetchLocalTracks(
            predicate: "a.relative_path IN (\(placeholders))",
            arguments: paths, orderBy: "a.relative_path"
        )
        return LocalMaintenancePage(tracks: tracks, nextPath: paths.last)
    }

    public func findUniqueTrack(title: String, artist: String?) async throws -> LocalTrack? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArtist = artist?.isEmpty == false
        let predicate = hasArtist
            ? """
              r.title = ? COLLATE NOCASE AND EXISTS (
                SELECT 1 FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id
                WHERE ac.entity_type = 'recording' AND ac.entity_id = r.id
                  AND art.name = ? COLLATE NOCASE)
              """
            : "r.title = ? COLLATE NOCASE"
        let matches = try await fetchLocalTracks(
            predicate: predicate,
            arguments: hasArtist ? [title, artist!] : [title],
            limit: 2
        )
        return matches.count == 1 ? matches[0] : nil
    }

    public func searchTracks(_ query: String, limit: Int) async throws -> [LocalTrack] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, limit > 0 else { return [] }
        return try await fetchLocalTracks(
            predicate: """
                instr(lower(r.title), lower(?)) > 0 OR EXISTS (
                    SELECT 1 FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id
                    WHERE ac.entity_type = 'recording' AND ac.entity_id = r.id
                      AND instr(lower(art.name), lower(?)) > 0)
                """,
            arguments: [needle, needle],
            limit: limit
        )
    }

    private func fetchLocalTracks(predicate: String, arguments: [String], limit: Int? = nil,
                                  orderBy: String = "album_title, track_number, track_title, a.relative_path") async throws -> [LocalTrack] {
        try await migrateLegacyManifestIfPresent()
        let mediaDir = try? mediaDirectory()
        let limitSQL = limit.map { " LIMIT \(max(1, min($0, 512)))" } ?? ""
        return try await db.reader.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.relative_path,
                       COALESCE(r.title, a.relative_path) AS track_title,
                       COALESCE(r.duration, a.duration, 0) AS duration,
                       COALESCE((SELECT art.name FROM artist_credits ac
                                 JOIN artists art ON art.id = ac.artist_id
                                 WHERE ac.entity_id = r.id AND ac.entity_type = 'recording'
                                 ORDER BY ac.position LIMIT 1), 'Unknown Artist') AS artist_name,
                       (SELECT rel.title FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                        WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS album_title,
                       (SELECT rel.release_year FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                        WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS release_year,
                       (SELECT rel.artwork_asset_id FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                        WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS artwork_asset_id,
                       (SELECT rt.track_number FROM release_tracks rt
                        WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS track_number
                FROM assets a JOIN sources s ON s.id = a.source_id
                LEFT JOIN recordings r ON r.id = a.recording_id
                WHERE s.source_type IN ('local_folder', 'localFolder') AND (\(predicate))
                ORDER BY \(orderBy)\(limitSQL)
                """, arguments: StatementArguments(arguments))
            return rows.compactMap { row -> LocalTrack? in
                guard let path: String = row["relative_path"] else { return nil }
                let url = path.hasPrefix("/") ? URL(fileURLWithPath: path)
                    : (mediaDir?.appendingPathComponent(path) ?? URL(fileURLWithPath: path))
                let rawNumber: String? = row["track_number"]
                return LocalTrack(
                    fileURL: url,
                    title: row["track_title"] ?? url.deletingPathExtension().lastPathComponent,
                    artist: row["artist_name"] ?? "Unknown Artist",
                    album: row["album_title"],
                    duration: row["duration"] ?? 0,
                    artworkReference: row["artwork_asset_id"],
                    trackNumber: rawNumber.flatMap { Int($0.prefix(while: { $0.isNumber })) },
                    year: row["release_year"]
                )
            }
        }
    }

    // MARK: - Save In Place

    public func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {
        guard !tracks.isEmpty else { return }

        let sourceRepo = SourceRepository(db: db)
        let identityRepo = IdentityRepository(db: db)
        let assetRepo = AssetRepository(db: db)
        let sourceID = SourceID("src_local_default")

        let defaultSource = Source(
            id: sourceID,
            sourceType: .localFolder,
            uri: "local://default",
            displayName: "Local Media Library",
            capabilities: .localFolderDefault,
            isEnabled: true
        )
        try await sourceRepo.insertOrUpdate(defaultSource)

        // Group tracks by album title to derive stable primary albumArtist (prevent duet fragmentation)
        var tracksByAlbum: [String: [LocalTrack]] = [:]
        for t in tracks {
            let alb = (t.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? t.album!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unknown Album"
            tracksByAlbum[alb, default: []].append(t)
        }

        var primaryArtistByAlbum: [String: String] = [:]
        for (alb, tList) in tracksByAlbum {
            let counts = tList.reduce(into: [String: Int]()) { $0[$1.artist, default: 0] += 1 }
            let cand = counts.max(by: { $0.value < $1.value })?.key ?? tList.first?.artist ?? "Unknown Artist"
            let primary = cand.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cand
            primaryArtistByAlbum[alb] = primary.isEmpty ? cand : primary
        }

        var artists: [(id: ArtistID, name: String)] = []
        var recordings: [(id: RecordingID, title: String, duration: Double?)] = []
        var releaseGroups: [(id: ReleaseGroupID, title: String)] = []
        var releases: [(id: ReleaseID, releaseGroupID: ReleaseGroupID?, title: String, year: Int?, artworkAssetID: String?)] = []
        var releaseTracks: [(id: ReleaseTrackID, releaseID: ReleaseID, trackNumber: Int, title: String, duration: Double?, recordingID: RecordingID)] = []
        var artistCredits: [(artistID: ArtistID, entityType: String, entityID: String)] = []
        var assets: [PersistedAssetRecord] = []
        var bookmarksToSave: [(assetID: String, bookmarkData: Data)] = []

        let bookmarkOptions = SecurityScopePolicy.bookmarkCreationOptions

        for track in tracks {
            let relTitle = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? track.album!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unknown Album"
            let albumArtist = primaryArtistByAlbum[relTitle] ?? track.artist
            let recID = DeterministicID.recording(title: track.title, artist: track.artist)
            let albumArtID = DeterministicID.artist(name: albumArtist)
            let trackArtID = DeterministicID.artist(name: track.artist)
            let rgID = DeterministicID.releaseGroup(artist: albumArtist, title: relTitle)
            let relID = DeterministicID.release(artist: albumArtist, title: relTitle)
            let trkID = DeterministicID.releaseTrack(releaseID: relID, medium: 1, track: track.trackNumber ?? 1)
            let relativePath = track.fileURL.standardizedFileURL.path
            let astID = DeterministicID.asset(sourceID: sourceID, relativePath: relativePath)

            artists.append((id: trackArtID, name: track.artist))
            if trackArtID != albumArtID {
                artists.append((id: albumArtID, name: albumArtist))
            }

            recordings.append((id: recID, title: track.title, duration: track.duration))
            releaseGroups.append((id: rgID, title: relTitle))

            var artRef = track.artworkReference
            if artRef == nil, let artData = track.artworkData {
                artRef = LocalArtworkStorage.shared.storeArtwork(artData)
            }
            releases.append((id: relID, releaseGroupID: rgID, title: relTitle, year: track.year, artworkAssetID: artRef))
            releaseTracks.append((id: trkID, releaseID: relID, trackNumber: track.trackNumber ?? 1, title: track.title, duration: track.duration, recordingID: recID))
            artistCredits.append((artistID: trackArtID, entityType: "recording", entityID: recID.rawValue))
            artistCredits.append((artistID: albumArtID, entityType: "release", entityID: relID.rawValue))

            assets.append(PersistedAssetRecord(
                id: astID,
                sourceID: sourceID,
                relativePath: relativePath,
                fileSize: 0,
                mtime: Date().timeIntervalSince1970,
                format: track.fileURL.pathExtension.uppercased(),
                duration: track.duration,
                recordingID: recID
            ))

            if let bookmark = try? track.fileURL.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarksToSave.append((assetID: astID.rawValue, bookmarkData: bookmark))
            }
        }

        try await identityRepo.batchUpsertEntities(
            artists: artists,
            recordings: recordings,
            releaseGroups: releaseGroups,
            releases: releases,
            releaseTracks: releaseTracks,
            artistCredits: artistCredits
        )
        try await assetRepo.batchUpsert(assets)

        // Save bookmarks to file_assets
        if !bookmarksToSave.isEmpty {
            let finalBookmarks = bookmarksToSave
            try await db.dbWriter.write { db in
                for item in finalBookmarks {
                    try db.execute(
                        sql: "UPDATE file_assets SET bookmark_blob = ? WHERE asset_id = ?",
                        arguments: [item.bookmarkData, item.assetID]
                    )
                }
            }
        }
    }

    public func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }

    public func batchUpsertTracks(_ tracks: [LocalTrack]) async throws {
        try await saveTracksInPlace(tracks)
    }

    // MARK: - Import

    public func importTrack(from url: URL) async throws -> LocalTrack? {
        let list = try await importTracks(from: [url])
        return list.first
    }

    public func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        try await importTracksDetailed(from: urls).tracks
    }

    public func importTracksDetailed(from urls: [URL]) async throws -> LocalImportResult {
        guard !urls.isEmpty else { return LocalImportResult(tracks: [], failures: []) }

        var readList: [LocalTrack] = []
        var failures: [LocalImportFailure] = []
        for url in urls {
            guard LocalAudioFormatSupport.supports(url) else {
                failures.append(LocalImportFailure(fileURL: url, reason: "Unsupported audio format"))
                continue
            }
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let track = try await readTrack(from: url)
                readList.append(track)
            } catch {
                failures.append(LocalImportFailure(fileURL: url, reason: error.localizedDescription))
            }
        }

        try await saveTracksInPlace(readList)
        return LocalImportResult(tracks: readList, failures: failures)
    }

    // MARK: - Delete

    public func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        guard !ids.isEmpty else { return }

        let normalizedPaths = Set(ids.map { id in
            if let url = URL(string: id), url.isFileURL { return url.standardizedFileURL.path }
            return URL(fileURLWithPath: id).standardizedFileURL.path
        })
        let orderedPaths = normalizedPaths.sorted()

        // Only registered local assets may be removed; never scan or match a remote source.
        let (matchedIDs, matchedUrls) = try await db.reader.read { db -> (Set<AssetID>, [URL]) in
            var ids = Set<AssetID>()
            var urls: [URL] = []
            for start in stride(from: 0, to: orderedPaths.count, by: 500) {
                let batch = Array(orderedPaths[start..<min(start + 500, orderedPaths.count)])
                let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
                let rows = try Row.fetchAll(db, sql: """
                    SELECT a.id, a.relative_path FROM assets a
                    JOIN sources s ON s.id = a.source_id
                    WHERE s.source_type IN ('local_folder', 'localFolder') AND a.relative_path IN (\(placeholders))
                    """, arguments: StatementArguments(batch))
                for row in rows {
                    if let raw: String = row["id"] { ids.insert(AssetID(raw)) }
                    if let path: String = row["relative_path"] { urls.append(URL(fileURLWithPath: path)) }
                }
            }
            return (ids, urls)
        }

        guard !matchedIDs.isEmpty else { return }

        var trashed: [(original: URL, destination: URL)] = []
        if deletePhysicalFiles {
            for fileURL in matchedUrls {
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }
                do {
                    var destination: NSURL?
                    try FileManager.default.trashItem(at: fileURL, resultingItemURL: &destination)
                    guard let destination = destination as URL? else { throw CocoaError(.fileWriteUnknown) }
                    trashed.append((fileURL, destination))
                } catch {
                    try restoreTrashedFiles(trashed, after: error)
                }
            }
        }

        do {
            let identityRepo = IdentityRepository(db: db)
            _ = try await identityRepo.deleteTracks(assetIDs: matchedIDs, cascadeLocalCollections: true)
        } catch {
            try restoreTrashedFiles(trashed, after: error)
        }
    }

    private func restoreTrashedFiles(_ trashed: [(original: URL, destination: URL)], after cause: Error) throws -> Never {
        var stranded: [String] = []
        for item in trashed.reversed() {
            do {
                try FileManager.default.moveItem(at: item.destination, to: item.original)
            } catch {
                stranded.append("\(item.destination.path) → \(item.original.path): \(error.localizedDescription)")
            }
        }
        if !stranded.isEmpty {
            throw LocalDeletionError.restorationFailed(cause.localizedDescription, stranded)
        }
        throw cause
    }

    // MARK: - Legacy Migration

    private func migrateLegacyManifestIfPresent() async throws {
        let manifestURL = try externalManifestURL()
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }
        let data = try Data(contentsOf: manifestURL)

        struct LegacyRecord: Codable {
            let fileURL: URL
            let title: String
            let artist: String
            let album: String?
            let duration: TimeInterval
            let artworkRelativePath: String?
            let trackNumber: Int?
            let year: Int?
        }

        let records = try JSONDecoder().decode([LegacyRecord].self, from: data)
        let expectedPaths = Set(records.map { $0.fileURL.standardizedFileURL.path })
        let existingPaths = try await db.reader.read { db in
            try Set(String.fetchAll(db, sql: "SELECT relative_path FROM assets WHERE source_id = ?",
                                    arguments: ["src_local_default"]))
        }
        let missing = records.filter { !existingPaths.contains($0.fileURL.standardizedFileURL.path) }
        if !missing.isEmpty {
            let tracks = missing.map { rec in
                LocalTrack(
                    fileURL: rec.fileURL,
                    title: rec.title,
                    artist: rec.artist,
                    album: rec.album,
                    duration: rec.duration,
                    artworkReference: rec.artworkRelativePath,
                    artworkData: nil,
                    trackNumber: rec.trackNumber,
                    year: rec.year
                )
            }
            try await saveTracksInPlace(tracks)
        }

        let persistedPaths = try await db.reader.read { db in
            try Set(String.fetchAll(db, sql: "SELECT relative_path FROM assets WHERE source_id = ?",
                                    arguments: ["src_local_default"]))
        }
        guard expectedPaths.isSubset(of: persistedPaths) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let backupURL = manifestURL.appendingPathExtension("legacy.backup")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            guard try Data(contentsOf: backupURL) == data else {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.removeItem(at: manifestURL)
        } else {
            try FileManager.default.moveItem(at: manifestURL, to: backupURL)
        }
    }

    private func externalManifestURL() throws -> URL {
        try mediaDirectory().appendingPathComponent("external_tracks.json")
    }

    // MARK: - Metadata Extraction

    public func readTrack(from url: URL) async throws -> LocalTrack {
        try await Self.readTrack(from: url)
    }

    public static func readTrack(from url: URL) async throws -> LocalTrack {
        let url = url.resolvingSymlinksInPath().standardizedFileURL
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadNoSuchFile) }
        let asset = AVURLAsset(url: url)

        // Fast path for DSD DSF files: bypass AVFoundation to prevent CoreAudio FFR errors
        if url.pathExtension.lowercased() == "dsf", let dsfMeta = DSFHeaderReader.readMetadata(from: url) {
            let parsed = FileNameHeuristicParser.parse(fileURL: url)
            let rule = PathHeuristicRuleStore.shared.match(fileURL: url)
            let title = dsfMeta.title ?? parsed.title
            let artist = dsfMeta.artist ?? rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
            var album = dsfMeta.album ?? rule?.targetAlbum ?? parsed.album
            if let alb = album, FileNameHeuristicParser.isGenericFolderName(alb) {
                album = nil
            }
            let artworkData = dsfMeta.artworkData ?? LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
            let trackNumber = dsfMeta.trackNumber ?? parsed.trackNumber
            let year = dsfMeta.year ?? parsed.year

            return LocalTrack(
                fileURL: url,
                title: title,
                artist: artist,
                album: album,
                duration: dsfMeta.duration,
                artworkData: artworkData,
                trackNumber: trackNumber,
                year: year
            )
        }

        var metadata: [AVMetadataItem] = []
        if let common = try? await asset.load(.commonMetadata) {
            metadata.append(contentsOf: common)
        }
        if let all = try? await asset.load(.metadata) {
            metadata.append(contentsOf: all)
        }
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for fmt in formats {
                if let items = try? await asset.loadMetadata(for: fmt) {
                    metadata.append(contentsOf: items)
                }
            }
        }

        // Title
        let parsed = FileNameHeuristicParser.parse(fileURL: url)
        let rule = PathHeuristicRuleStore.shared.match(fileURL: url)

        let rawTitle = await metadataString(
            identifier: .commonIdentifierTitle,
            alternateKeys: ["title"],
            metadata: metadata
        )
        let title = (rawTitle != nil && !rawTitle!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawTitle!
            : parsed.title

        // Artist
        let rawArtist = await metadataString(
            identifier: .commonIdentifierArtist,
            alternateKeys: ["artist", "albumartist", "composer"],
            metadata: metadata
        )
        let artist: String
        if let rawArtist, !rawArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, rawArtist != "Unknown Artist" {
            artist = rawArtist
        } else {
            artist = rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
        }

        // Clean redundant artist prefix from title if present (e.g. "李克勤-一生不变" -> "一生不变")
        var finalTitle = title
        if finalTitle.lowercased().hasPrefix(artist.lowercased()) {
            let stripped = finalTitle.dropFirst(artist.count).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_"))
            if !stripped.isEmpty {
                finalTitle = stripped
            }
        }

        // Album
        let rawAlbum = await metadataString(
            identifier: .commonIdentifierAlbumName,
            alternateKeys: ["album"],
            metadata: metadata
        )
        var finalAlbum = (rawAlbum != nil && !rawAlbum!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawAlbum
            : (rule?.targetAlbum ?? parsed.album)

        // Safety gate: never allow album == artist or generic folder name
        if let alb = finalAlbum {
            let trimmed = alb.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() == artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() || FileNameHeuristicParser.isGenericFolderName(trimmed) {
                finalAlbum = nil
            }
        }

        // Artwork
        var artworkData = await metadataData(
            identifier: .commonIdentifierArtwork,
            metadata: metadata
        )
        if artworkData == nil {
            artworkData = LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
        }

        // TrackNumber & Year
        var trackNumber: Int? = parsed.trackNumber
        if let rawTrk = await metadataString(identifier: .id3MetadataTrackNumber, alternateKeys: ["tracknumber", "trck"], metadata: metadata) {
            let digits = rawTrk.prefix(while: { $0.isNumber })
            if let num = Int(digits) {
                trackNumber = num
            }
        }

        var year: Int? = parsed.year
        if let rawDate = await metadataString(identifier: .id3MetadataYear, alternateKeys: ["date", "year", "tyer", "tdrc"], metadata: metadata) {
            let digits = rawDate.prefix(while: { $0.isNumber })
            if digits.count >= 4, let yr = Int(digits.prefix(4)) {
                year = yr
            }
        }

        // Duration
        let duration: TimeInterval
        do {
            let durationValue = try await asset.load(.duration)
            let seconds = durationValue.seconds
            duration = seconds.isFinite && seconds > 0 ? seconds : 0
        } catch {
            duration = 0
        }

        return LocalTrack(
            fileURL: url,
            title: finalTitle,
            artist: artist,
            album: finalAlbum,
            duration: duration,
            artworkData: artworkData,
            trackNumber: trackNumber,
            year: year
        )
    }

    private static func metadataString(
        identifier: AVMetadataIdentifier,
        alternateKeys: [String] = [],
        metadata: [AVMetadataItem]
    ) async -> String? {
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let lowerAlts = alternateKeys.map { $0.lowercased() }
        for item in metadata {
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            for alt in lowerAlts {
                if keyStr == alt || idStr == alt || idStr.hasSuffix("/" + alt) {
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return nil
    }

    private static func metadataData(
        identifier: AVMetadataIdentifier,
        metadata: [AVMetadataItem]
    ) async -> Data? {
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                return data
            }
        }

        for item in metadata {
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            if idStr.contains("picture") || keyStr.contains("picture") || idStr.contains("artwork") || keyStr.contains("artwork") {
                if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                    return data
                }
            }
        }

        for item in metadata {
            if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                return data
            }
        }
        return nil
    }

    private func mediaDirectory() throws -> URL {
        if let directory {
            return directory
        }
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "SQLiteLocalLibraryRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access application support directory."])
        }
        let resolved = support.appendingPathComponent("MSRU/LocalMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
        return resolved
    }
}

private enum LocalDeletionError: LocalizedError {
    case restorationFailed(String, [String])

    public var errorDescription: String? {
        switch self {
        case .restorationFailed(let cause, let paths):
            return "File deletion failed (\(cause)). Some files could not be restored: \(paths.joined(separator: "; "))"
        }
    }
}
