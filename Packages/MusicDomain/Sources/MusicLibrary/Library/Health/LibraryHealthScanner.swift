//
//  LibraryHealthScanner.swift
//  MSRU
//
//  Finds what needs cleaning in the local library: possible duplicates,
//  placeholder or missing metadata and missing artwork. It reads the index in
//  keyset pages on the database reader and classifies rows on its own actor,
//  so it never touches files or the main actor and scales to very large
//  libraries. Only local files are scanned: they are the only sources MSRU can
//  fix or remove.
//

import Foundation
import GRDB
import MusicDomain

// MARK: - Report

/// What is wrong with one track's displayed metadata.
nonisolated public struct LibraryMetadataIssues: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let placeholderTitle = LibraryMetadataIssues(rawValue: 1 << 0)
    public static let unknownArtist = LibraryMetadataIssues(rawValue: 1 << 1)
    public static let missingAlbum = LibraryMetadataIssues(rawValue: 1 << 2)
    public static let missingArtwork = LibraryMetadataIssues(rawValue: 1 << 3)

    /// Issues that "Get Info" (catalogue lookup) can resolve.
    public static let incompleteInfo: LibraryMetadataIssues = [.placeholderTitle, .unknownArtist, .missingAlbum]
}

/// One scanned local file, with the facts needed to compare copies.
nonisolated public struct LibraryHealthTrack: Sendable, Hashable {
    /// Stored asset path; also accepted as a track ID by the library repository.
    public let path: String
    public let title: String
    public let artist: String
    public let duration: TimeInterval
    public let format: String
    public let bitrateKbps: Int?
    public let fileSize: Int64

    public init(path: String, title: String, artist: String, duration: TimeInterval,
                format: String, bitrateKbps: Int?, fileSize: Int64) {
        self.path = path
        self.title = title
        self.artist = artist
        self.duration = duration
        self.format = format
        self.bitrateKbps = bitrateKbps
        self.fileSize = fileSize
    }
}

/// Tracks that share a normalized artist and title and a similar duration.
/// They are candidates: the duplicate classifier decides which are true copies.
nonisolated public struct LibraryDuplicateCandidateGroup: Sendable, Hashable, Identifiable {
    public let tracks: [LibraryHealthTrack]
    public var id: String { tracks.first?.path ?? "" }

    public init(tracks: [LibraryHealthTrack]) {
        self.tracks = tracks
    }
}

nonisolated public struct LibraryHealthReport: Sendable {
    public let scannedAt: Date
    public let trackCount: Int
    public let duplicateGroups: [LibraryDuplicateCandidateGroup]
    /// Paths of tracks with a placeholder title, unknown artist or missing album.
    public let incompleteInfoPaths: [String]
    public let missingArtworkPaths: [String]
    public let placeholderTitleCount: Int
    public let unknownArtistCount: Int
    public let missingAlbumCount: Int

    public init(
        scannedAt: Date = Date(),
        trackCount: Int,
        duplicateGroups: [LibraryDuplicateCandidateGroup],
        incompleteInfoPaths: [String],
        missingArtworkPaths: [String],
        placeholderTitleCount: Int,
        unknownArtistCount: Int,
        missingAlbumCount: Int
    ) {
        self.scannedAt = scannedAt
        self.trackCount = trackCount
        self.duplicateGroups = duplicateGroups
        self.incompleteInfoPaths = incompleteInfoPaths
        self.missingArtworkPaths = missingArtworkPaths
        self.placeholderTitleCount = placeholderTitleCount
        self.unknownArtistCount = unknownArtistCount
        self.missingAlbumCount = missingAlbumCount
    }

    public var duplicateCandidatePaths: [String] {
        duplicateGroups.flatMap { $0.tracks.map(\.path) }
    }

    /// Copies beyond the first in each candidate group.
    public var possibleExtraCopies: Int {
        duplicateGroups.reduce(0) { $0 + max(0, $1.tracks.count - 1) }
    }

    public var isClean: Bool {
        duplicateGroups.isEmpty && incompleteInfoPaths.isEmpty && missingArtworkPaths.isEmpty
    }
}

nonisolated public struct LibraryHealthProgress: Sendable, Equatable {
    public let scanned: Int
    public let total: Int

    public init(scanned: Int, total: Int) {
        self.scanned = scanned
        self.total = total
    }

    public var fraction: Double {
        total > 0 ? min(1, Double(scanned) / Double(total)) : 0
    }
}

// MARK: - Rules

/// Classification rules. Pure functions so they are testable without a database.
nonisolated public enum LibraryHealthRules {
    /// Duration difference within which two recordings may be the same one.
    public static let durationTolerance: TimeInterval = 6

    public static func issues(
        title: String?,
        artist: String?,
        album: String?,
        artwork: String?,
        fileStem: String
    ) -> LibraryMetadataIssues {
        var issues: LibraryMetadataIssues = []
        if isPlaceholderTitle(title, fileStem: fileStem) { issues.insert(.placeholderTitle) }
        if isUnknown(artist, tokens: unknownArtistTokens) { issues.insert(.unknownArtist) }
        if isUnknown(album, tokens: unknownAlbumTokens) { issues.insert(.missingAlbum) }
        if artwork?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true { issues.insert(.missingArtwork) }
        return issues
    }

    /// True for titles that carry no information: empty, "Track 05", "track05",
    /// "Untitled", "音轨 5", a bare number taken from the file name, or the raw
    /// file name of a numbered file. ("Song 2" and "22" are real titles.)
    public static func isPlaceholderTitle(_ title: String?, fileStem: String) -> Bool {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return true }

        let lowered = trimmed.lowercased()
        let word = placeholderWords.first { lowered.hasPrefix($0) }
        let rest = lowered.dropFirst(word?.count ?? 0).drop(while: { separatorCharacters.contains($0) })
        if rest.isEmpty { return true }
        // Bare numbers are placeholders only when they carry a word like "Track"
        // or came from the file name: "22" and "1999" are real titles.
        if rest.count <= 3, rest.allSatisfy({ $0.isASCIIDigit }) {
            return word != nil || trimmed == fileStem
        }

        // A title equal to a numbered file name ("01 - Song") was taken from the
        // file name because the file had no title tag.
        if trimmed == fileStem, startsWithTrackNumber(fileStem) { return true }
        return false
    }

    public static func isUnknownArtist(_ artist: String?) -> Bool {
        isUnknown(artist, tokens: unknownArtistTokens)
    }

    /// Key under which two tracks may be the same song, or nil when the metadata
    /// is too poor to compare (placeholder title or unknown artist).
    public static func duplicateKey(title: String, artist: String, fileStem: String) -> String? {
        guard !isPlaceholderTitle(title, fileStem: fileStem), !isUnknownArtist(artist) else { return nil }
        let artistKey = fold(primaryArtist(artist))
        let titleKey = fold(stripVersionQualifiers(title))
        guard !artistKey.isEmpty, !titleKey.isEmpty else { return nil }
        return artistKey + "::" + titleKey
    }

    /// Splits tracks sharing a key into runs whose durations stay within the tolerance.
    public static func partitionByDuration(_ tracks: [LibraryHealthTrack]) -> [[LibraryHealthTrack]] {
        let sorted = tracks.sorted { $0.duration < $1.duration }
        var groups: [[LibraryHealthTrack]] = []
        for track in sorted {
            if let anchor = groups.last?.first, track.duration - anchor.duration <= durationTolerance {
                groups[groups.count - 1].append(track)
            } else {
                groups.append([track])
            }
        }
        return groups
    }

    // MARK: Helpers

    private static let placeholderWords = [
        "track", "audio", "untitled", "unknown", "piste", "pista",
        "トラック", "曲目", "音轨", "音軌", "未命名", "未知"
    ]
    private static let separatorCharacters: Set<Character> = [" ", "_", "-", ".", "#", "(", ")", "[", "]"]
    private static let unknownArtistTokens: Set<String> = [
        "unknown", "unknown artist", "<unknown>", "未知", "未知艺术家", "未知歌手", "未知藝人", "未知歌手"
    ]
    private static let unknownAlbumTokens: Set<String> = [
        "unknown", "unknown album", "<unknown>", "未知", "未知专辑", "未知專輯"
    ]
    private static let versionKeywords = [
        "feat", "ft.", "featuring", "with ", "live", "remaster", "deluxe", "version",
        "edition", "mono", "stereo", "bonus", "acoustic", "radio edit", "original mix"
    ]
    private static let artistSeparators = [" feat. ", " ft. ", " featuring ", " & ", " / ", ", ", "、"]

    private static func isUnknown(_ value: String?, tokens: Set<String>) -> Bool {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty || tokens.contains(normalized)
    }

    private static func startsWithTrackNumber(_ stem: String) -> Bool {
        let digits = stem.prefix(while: { $0.isASCIIDigit })
        guard (1...3).contains(digits.count) else { return false }
        guard let next = stem.dropFirst(digits.count).first else { return false }
        return separatorCharacters.contains(next)
    }

    private static func primaryArtist(_ artist: String) -> String {
        var result = artist
        for separator in artistSeparators {
            if let range = result.range(of: separator, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result
    }

    /// Drops bracketed qualifiers ("(Live)", "[2011 Remaster]", "(feat. X)") and
    /// " - Live…" style suffixes, so versions of one song share a key. The
    /// duplicate classifier still grades them as versions, not copies.
    private static func stripVersionQualifiers(_ title: String) -> String {
        var result = ""
        var bracketDepth = 0
        var bracketContent = ""
        for character in title {
            if "([{（【".contains(character) {
                bracketDepth += 1
                if bracketDepth == 1 { bracketContent = "" ; continue }
            } else if ")]}）】".contains(character), bracketDepth > 0 {
                bracketDepth -= 1
                if bracketDepth == 0 {
                    let lowered = bracketContent.lowercased()
                    if !versionKeywords.contains(where: { lowered.contains($0) }) {
                        result += " " + bracketContent + " "
                    }
                    continue
                }
            }
            if bracketDepth > 0 {
                bracketContent.append(character)
            } else {
                result.append(character)
            }
        }
        if let dash = result.range(of: " - ") {
            let tail = result[dash.upperBound...].lowercased()
            if versionKeywords.contains(where: { tail.hasPrefix($0) }) || tail.first?.isASCIIDigit == true {
                result = String(result[..<dash.lowerBound])
            }
        }
        return result
    }

    /// Case-, width- and diacritic-insensitive letters and digits only.
    private static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
}

private extension Character {
    nonisolated var isASCIIDigit: Bool { isASCII && isNumber }
}

// MARK: - Scanner

public actor LibraryHealthScanner {
    nonisolated public static let pageSize = 2_000

    private let db: AppDatabase

    public init(db: AppDatabase) {
        self.db = db
    }

    /// Scans every local file once. Cancelling the calling task stops the scan.
    public func scan(progress: (@Sendable (LibraryHealthProgress) -> Void)? = nil) async throws -> LibraryHealthReport {
        let total = try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets a JOIN sources s ON s.id = a.source_id WHERE \(Self.localSourcePredicate)") ?? 0
        }
        progress?(LibraryHealthProgress(scanned: 0, total: total))

        var cursor: String?
        var scanned = 0
        var buckets: [String: [LibraryHealthTrack]] = [:]
        var incomplete: [String] = []
        var missingArtwork: [String] = []
        var placeholderTitles = 0
        var unknownArtists = 0
        var missingAlbums = 0

        while true {
            try Task.checkCancellation()
            let after = cursor
            let rows = try await db.reader.read { db in
                try Self.fetchPage(after: after, limit: Self.pageSize, in: db)
            }
            guard let last = rows.last else { break }
            cursor = last.track.path

            for row in rows {
                let stem = URL(fileURLWithPath: row.track.path).deletingPathExtension().lastPathComponent
                let issues = LibraryHealthRules.issues(
                    title: row.track.title, artist: row.track.artist,
                    album: row.album, artwork: row.artwork, fileStem: stem
                )
                if issues.contains(.placeholderTitle) { placeholderTitles += 1 }
                if issues.contains(.unknownArtist) { unknownArtists += 1 }
                if issues.contains(.missingAlbum) { missingAlbums += 1 }
                if !issues.isDisjoint(with: .incompleteInfo) { incomplete.append(row.track.path) }
                if issues.contains(.missingArtwork) { missingArtwork.append(row.track.path) }

                if let key = LibraryHealthRules.duplicateKey(title: row.track.title, artist: row.track.artist, fileStem: stem) {
                    buckets[key, default: []].append(row.track)
                }
            }
            scanned += rows.count
            progress?(LibraryHealthProgress(scanned: scanned, total: max(total, scanned)))
        }

        var groups: [LibraryDuplicateCandidateGroup] = []
        for tracks in buckets.values where tracks.count > 1 {
            for run in LibraryHealthRules.partitionByDuration(tracks) where run.count > 1 {
                groups.append(LibraryDuplicateCandidateGroup(tracks: run))
            }
        }
        groups.sort { ($0.tracks.first?.title ?? "").localizedStandardCompare($1.tracks.first?.title ?? "") == .orderedAscending }

        return LibraryHealthReport(
            trackCount: scanned,
            duplicateGroups: groups,
            incompleteInfoPaths: incomplete,
            missingArtworkPaths: missingArtwork,
            placeholderTitleCount: placeholderTitles,
            unknownArtistCount: unknownArtists,
            missingAlbumCount: missingAlbums
        )
    }

    // MARK: Query

    nonisolated private struct ScannedRow: Sendable {
        let track: LibraryHealthTrack
        let album: String?
        let artwork: String?
    }

    nonisolated private static let localSourcePredicate = "s.source_type IN ('local_folder', 'localFolder')"

    /// One page of local files after `after` (by path), with displayed metadata:
    /// user corrections win over scanned values, as in the Songs list.
    nonisolated private static func fetchPage(after: String?, limit: Int, in db: Database) throws -> [ScannedRow] {
        let sql = """
            SELECT a.relative_path AS path, a.format, a.bitrate_kbps, a.file_size,
                   COALESCE(r.duration, a.duration, 0) AS duration,
                   \(MetadataCorrections.corrected(.title, recordingColumn: "r.id", fallback: "r.title")) AS title,
                   \(MetadataCorrections.corrected(.artist, recordingColumn: "r.id", fallback: """
                       (SELECT art.name FROM artist_credits ac JOIN artists art ON art.id = ac.artist_id
                        WHERE ac.entity_id = r.id AND ac.entity_type = 'recording'
                        ORDER BY ac.position LIMIT 1)
                       """)) AS artist,
                   \(MetadataCorrections.corrected(.album, recordingColumn: "r.id", fallback: """
                       (SELECT rel.title FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                        WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1)
                       """)) AS album,
                   (SELECT rel.artwork_asset_id FROM release_tracks rt JOIN releases rel ON rel.id = rt.release_id
                    WHERE rt.recording_id = r.id ORDER BY rt.id LIMIT 1) AS artwork
            FROM assets a JOIN sources s ON s.id = a.source_id
            LEFT JOIN recordings r ON r.id = a.recording_id
            WHERE \(localSourcePredicate) AND (? IS NULL OR a.relative_path > ?)
            ORDER BY a.relative_path
            LIMIT ?
            """
        return try Row.fetchAll(db, sql: sql, arguments: [after, after, limit]).compactMap { row in
            guard let path: String = row["path"] else { return nil }
            let fileSize: Int64? = row["file_size"]
            return ScannedRow(
                track: LibraryHealthTrack(
                    path: path,
                    title: row["title"] ?? "",
                    artist: row["artist"] ?? "",
                    duration: row["duration"] ?? 0,
                    format: row["format"] ?? "",
                    bitrateKbps: row["bitrate_kbps"],
                    fileSize: fileSize ?? 0
                ),
                album: row["album"],
                artwork: row["artwork"]
            )
        }
    }
}
