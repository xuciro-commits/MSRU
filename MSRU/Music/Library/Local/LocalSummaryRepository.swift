import Foundation
import AppFoundation
import GRDB
import MusicDomain

nonisolated struct LocalSummaryPage<Item: Sendable>: Sendable {
    let items: [Item]
    let totalCount: Int
    let offset: Int
    var hasMore: Bool { offset + items.count < totalCount }
}

/// Reads local album and artist cards in bounded pages. Detail routes use exact IDs.
actor LocalSummaryRepository {
    enum AlbumSort: String, Sendable { case title, artist, year }

    private let db: AppDatabase

    init(db: AppDatabase = .shared) { self.db = db }

    func albumPage(query: String = "", sort: AlbumSort = .title,
                   offset: Int = 0, limit: Int = 64) async throws -> LocalSummaryPage<AlbumPresentationModel> {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedOffset = max(0, offset)
        let boundedLimit = min(max(1, limit), 256)
        let filter = needle.isEmpty ? "" : " AND (instr(lower(rel.title), lower(?)) > 0 OR EXISTS (SELECT 1 FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id WHERE ac.entity_type = 'release' AND ac.entity_id = rel.id AND instr(lower(art.name), lower(?)) > 0))"
        let args: StatementArguments = needle.isEmpty ? [] : [needle, needle]
        let order: String
        switch sort {
        case .title: order = "rel.sort_title ASC, rel.id ASC"
        case .artist: order = "artist_name ASC, rel.sort_title ASC, rel.id ASC"
        case .year: order = "rel.release_year DESC, rel.sort_title ASC, rel.id ASC"
        }
        return try await db.reader.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM releases rel WHERE \(Self.localAlbumPredicate)\(filter)", arguments: args) ?? 0
            let rows = try Row.fetchAll(db, sql: Self.albumSelect +
                " WHERE \(Self.localAlbumPredicate)\(filter) ORDER BY \(order) LIMIT ? OFFSET ?",
                arguments: args + [boundedLimit, boundedOffset])
            return LocalSummaryPage(items: rows.map(Self.album), totalCount: count, offset: boundedOffset)
        }
    }

    func artistPage(query: String = "", offset: Int = 0,
                    limit: Int = 64) async throws -> LocalSummaryPage<ArtistPresentationModel> {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedOffset = max(0, offset)
        let boundedLimit = min(max(1, limit), 256)
        let filter = needle.isEmpty ? "" : " AND instr(lower(art.name), lower(?)) > 0"
        let args: StatementArguments = needle.isEmpty ? [] : [needle]
        return try await db.reader.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists art WHERE \(Self.localArtistPredicate)\(filter)", arguments: args) ?? 0
            let rows = try Row.fetchAll(db, sql: Self.artistSelect +
                " WHERE \(Self.localArtistPredicate)\(filter) ORDER BY art.sort_name ASC, art.id ASC LIMIT ? OFFSET ?",
                arguments: args + [boundedLimit, boundedOffset])
            return LocalSummaryPage(items: rows.map(Self.artist), totalCount: count, offset: boundedOffset)
        }
    }

    func album(id: String) async throws -> AlbumPresentationModel? {
        try await db.reader.read { db in
            try Row.fetchOne(db, sql: Self.albumSelect + " WHERE rel.id = ? AND \(Self.localAlbumPredicate)", arguments: [id]).map(Self.album)
        }
    }

    func artist(id: String) async throws -> ArtistPresentationModel? {
        try await db.reader.read { db in
            try Row.fetchOne(db, sql: Self.artistSelect + " WHERE art.id = ? AND \(Self.localArtistPredicate)", arguments: [id]).map(Self.artist)
        }
    }

    nonisolated private static let localAlbumPredicate = """
        EXISTS (SELECT 1 FROM release_tracks rt JOIN assets ast ON ast.recording_id = rt.recording_id
                JOIN sources src ON src.id = ast.source_id WHERE rt.release_id = rel.id
                AND src.source_type IN ('local_folder', 'localFolder'))
        """

    nonisolated private static let localArtistPredicate = """
        EXISTS (SELECT 1 FROM artist_credits ac JOIN assets ast ON ast.recording_id = ac.entity_id
                JOIN sources src ON src.id = ast.source_id WHERE ac.artist_id = art.id
                AND ac.entity_type = 'recording' AND src.source_type IN ('local_folder', 'localFolder'))
        """

    nonisolated private static let albumSelect = """
        SELECT rel.id, rel.title, rel.release_year, rel.artwork_asset_id,
               COALESCE((SELECT art.name FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id
                         WHERE ac.entity_type = 'release' AND ac.entity_id = rel.id
                         ORDER BY ac.position LIMIT 1), 'Unknown Artist') AS artist_name,
               (SELECT COUNT(DISTINCT rt.recording_id) FROM release_tracks rt
                JOIN assets ast ON ast.recording_id = rt.recording_id
                JOIN sources src ON src.id = ast.source_id WHERE rt.release_id = rel.id
                AND src.source_type IN ('local_folder', 'localFolder')) AS track_count,
               (SELECT COALESCE(SUM(COALESCE(rec.duration, 0)), 0) FROM release_tracks rt
                JOIN recordings rec ON rec.id = rt.recording_id WHERE rt.release_id = rel.id
                AND EXISTS (SELECT 1 FROM assets ast JOIN sources src ON src.id = ast.source_id
                            WHERE ast.recording_id = rt.recording_id
                            AND src.source_type IN ('local_folder', 'localFolder'))) AS total_duration,
               (SELECT src.display_name FROM release_tracks rt JOIN assets ast ON ast.recording_id = rt.recording_id
                JOIN sources src ON src.id = ast.source_id WHERE rt.release_id = rel.id
                AND src.source_type IN ('local_folder', 'localFolder') LIMIT 1) AS source_badge,
               (SELECT COUNT(DISTINCT ast.source_id) FROM release_tracks rt
                JOIN assets ast ON ast.recording_id = rt.recording_id JOIN sources src ON src.id = ast.source_id
                WHERE rt.release_id = rel.id AND src.source_type IN ('local_folder', 'localFolder')) AS version_count
        FROM releases rel
        """

    nonisolated private static let artistSelect = """
        SELECT art.id, art.name,
               (SELECT COUNT(DISTINCT ac.entity_id) FROM artist_credits ac
                JOIN assets ast ON ast.recording_id = ac.entity_id JOIN sources src ON src.id = ast.source_id
                WHERE ac.artist_id = art.id AND ac.entity_type = 'recording'
                AND src.source_type IN ('local_folder', 'localFolder')) AS track_count,
               (SELECT COUNT(DISTINCT ac.entity_id) FROM artist_credits ac
                JOIN release_tracks rt ON rt.release_id = ac.entity_id
                JOIN assets ast ON ast.recording_id = rt.recording_id JOIN sources src ON src.id = ast.source_id
                WHERE ac.artist_id = art.id AND ac.entity_type = 'release'
                AND src.source_type IN ('local_folder', 'localFolder')) AS album_count,
               (SELECT rel.artwork_asset_id FROM releases rel JOIN artist_credits ac ON ac.entity_id = rel.id
                WHERE ac.artist_id = art.id AND ac.entity_type = 'release'
                AND rel.artwork_asset_id IS NOT NULL LIMIT 1) AS artwork_ref
        FROM artists art
        """

    nonisolated private static func album(_ row: Row) -> AlbumPresentationModel {
        AlbumPresentationModel(
            id: row["id"], title: row["title"], artist: row["artist_name"],
            year: row["release_year"], artworkReference: row["artwork_asset_id"],
            trackCount: row["track_count"], duration: row["total_duration"],
            sourceBadge: row["source_badge"], versionCount: max(1, row["version_count"] ?? 1)
        )
    }

    nonisolated private static func artist(_ row: Row) -> ArtistPresentationModel {
        ArtistPresentationModel(
            id: row["id"], name: row["name"], albumCount: row["album_count"],
            trackCount: row["track_count"], artworkReference: row["artwork_ref"]
        )
    }
}
