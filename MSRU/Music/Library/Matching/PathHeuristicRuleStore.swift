//
//  PathHeuristicRuleStore.swift
//  MSRU
//
//  Created for Directory Path Heuristics & Local Rule Learning.
//

import Foundation
import Observation
import GRDB

/// A directory path pattern that maps to an artist entity and optional album.
public struct PathHeuristicRule: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var pathPattern: String     // e.g. "王力宏" or "男歌手/王力宏"
    public var targetArtist: String    // e.g. "王力宏"
    public var targetAlbum: String?    // optional
    public var matchCount: Int
    public var dateAdded: Date

    public init(
        id: UUID = UUID(),
        pathPattern: String,
        targetArtist: String,
        targetAlbum: String? = nil,
        matchCount: Int = 0,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.pathPattern = pathPattern
        self.targetArtist = targetArtist
        self.targetAlbum = targetAlbum
        self.matchCount = matchCount
        self.dateAdded = dateAdded
    }
}

/// Central store for managing directory path heuristic matching and auto-learning rules.
@MainActor
@Observable
public final class PathHeuristicRuleStore {
    public static let shared = PathHeuristicRuleStore()

    public private(set) var rules: [PathHeuristicRule] = []
    public private(set) var persistenceWriteCount: Int = 0
    private let db: AppDatabase
    private let legacyStorageURL: URL?

    public init(db: AppDatabase = .shared, legacyStorageURL: URL? = nil) {
        self.db = db
        if let legacyStorageURL {
            self.legacyStorageURL = legacyStorageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Rules", isDirectory: true)
            self.legacyStorageURL = dir.appendingPathComponent("path_heuristic_rules.json")
        }
        migrateLegacyFileIfNeeded()
        load()
    }

    public convenience init(storageURL: URL?) {
        self.init(db: .shared, legacyStorageURL: storageURL)
    }

    /// Evaluates a file URL against all rules. Returns the best matching rule.
    public static let genericFolderNames: Set<String> = [
        "music", "audio", "media", "songs", "tracks", "downloads", "desktop", "documents", "library", "files"
    ]

    public func match(fileURL: URL) -> PathHeuristicRule? {
        let pathLower = fileURL.path.lowercased()
        let components = fileURL.pathComponents.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        for (index, rule) in rules.enumerated() {
            let pattern = rule.pathPattern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pattern.isEmpty else { continue }
            guard !Self.genericFolderNames.contains(pattern) else { continue }
            let isMatch: Bool
            if pattern.contains("/") {
                isMatch = pathLower.contains(pattern)
            } else {
                isMatch = components.contains(pattern)
            }
            if isMatch {
                rules[index].matchCount += 1
                save()
                return rule
            }
        }
        return nil
    }

    /// Adds or updates a heuristic rule.
    @discardableResult
    public func addRule(pathPattern: String, targetArtist: String, targetAlbum: String? = nil, autoSave: Bool = true) -> Bool {
        let cleanPattern = pathPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = targetArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPattern.isEmpty, !cleanArtist.isEmpty, cleanArtist != "Unknown Artist" else { return false }
        guard !Self.genericFolderNames.contains(cleanPattern.lowercased()) else { return false }

        var changed = false
        if let idx = rules.firstIndex(where: { $0.pathPattern.lowercased() == cleanPattern.lowercased() }) {
            if rules[idx].targetArtist != cleanArtist || rules[idx].targetAlbum != targetAlbum {
                rules[idx].targetArtist = cleanArtist
                rules[idx].targetAlbum = targetAlbum
                changed = true
            }
        } else {
            rules.append(PathHeuristicRule(
                pathPattern: cleanPattern,
                targetArtist: cleanArtist,
                targetAlbum: targetAlbum
            ))
            changed = true
        }

        if changed && autoSave {
            save()
        }
        return changed
    }

    /// Removes a rule by its ID.
    public func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
        save()
    }

    /// Clears all rules.
    public func removeAll() {
        rules.removeAll()
        save()
    }

    /// Automatically learns a rule from an imported folder and identified artist.
    @discardableResult
    public func learnFrom(folderURL: URL?, artist: String, album: String? = nil, autoSave: Bool = true) -> Bool {
        guard let folderURL else { return false }
        let folderName = folderURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderName.isEmpty, folderName != "/" else { return false }
        guard !Self.genericFolderNames.contains(folderName.lowercased()) else { return false }

        var finalArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)

        // If artist is Unknown or empty, try extracting from folder name like "Artist - Album"
        if finalArtist.isEmpty || finalArtist == "Unknown Artist" {
            if let extracted = Self.extractArtistAndAlbum(from: folderName) {
                finalArtist = extracted.artist
                if finalAlbum == nil || finalAlbum?.isEmpty == true {
                    finalAlbum = extracted.album
                }
            } else {
                // Cannot infer a valid artist, do not learn a polluted rule
                return false
            }
        }

        return addRule(pathPattern: folderName, targetArtist: finalArtist, targetAlbum: finalAlbum, autoSave: autoSave)
    }

    /// Batched rule learning from a collection of tracks with single atomic write if changed.
    public func learnBatch(from tracks: [LocalTrack]) {
        var changed = false
        for track in tracks {
            if learnFrom(folderURL: track.fileURL.deletingLastPathComponent(), artist: track.artist, album: track.album, autoSave: false) {
                changed = true
            }
        }
        if changed {
            save()
        }
    }

    /// Extracts artist and album from patterns like "刘达 - 甄选2024(24K金碟头版限量)"
    public static func extractArtistAndAlbum(from string: String) -> (artist: String, album: String?)? {
        let separators = [" - ", "－", " – ", " — "]
        for sep in separators {
            if string.contains(sep) {
                let parts = string.components(separatedBy: sep)
                if parts.count >= 2 {
                    let artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let album = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !artist.isEmpty && artist != "Unknown Artist" {
                        return (artist: artist, album: album.isEmpty ? nil : album)
                    }
                }
            }
        }
        return nil
    }

    private func migrateLegacyFileIfNeeded() {
        guard let legacyStorageURL, FileManager.default.fileExists(atPath: legacyStorageURL.path) else { return }
        do {
            let data = try Data(contentsOf: legacyStorageURL)
            let legacyRules = try JSONDecoder().decode([PathHeuristicRule].self, from: data)
            try db.dbWriter.write { db in
                for rule in legacyRules {
                    try db.execute(
                        sql: """
                        INSERT OR IGNORE INTO path_heuristic_rules
                        (id, path_pattern, target_artist, target_album, confidence, learned_at, hit_count)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            rule.id.uuidString,
                            rule.pathPattern,
                            rule.targetArtist,
                            rule.targetAlbum,
                            1.0,
                            rule.dateAdded,
                            rule.matchCount
                        ]
                    )
                }
            }
            try? FileManager.default.removeItem(at: legacyStorageURL)
            print("[PathHeuristicRuleStore] Migrated legacy path_heuristic_rules.json to SQLite and removed file.")
        } catch {
            print("[PathHeuristicRuleStore] Failed migrating legacy rules: \(error)")
            try? FileManager.default.removeItem(at: legacyStorageURL)
        }
    }

    private func load() {
        do {
            let rows = try db.reader.read { db in
                try Row.fetchAll(db, sql: "SELECT id, path_pattern, target_artist, target_album, hit_count, learned_at FROM path_heuristic_rules ORDER BY learned_at DESC")
            }

            var loadedRules: [PathHeuristicRule] = []
            var didModify = false

            for row in rows {
                let idStr: String = row["id"]
                let patternStr: String = row["path_pattern"]
                let artistStr: String? = row["target_artist"]
                let albumStr: String? = row["target_album"]
                let hitCount: Int = row["hit_count"]
                let learnedAt: Date = row["learned_at"]

                let pattern = patternStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if Self.genericFolderNames.contains(pattern) {
                    didModify = true
                    continue
                }

                var cleanArtist = (artistStr ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                var cleanAlbum = albumStr?.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanArtist.isEmpty || cleanArtist == "Unknown Artist" {
                    if let extracted = Self.extractArtistAndAlbum(from: patternStr) {
                        cleanArtist = extracted.artist
                        if cleanAlbum == nil || cleanAlbum?.isEmpty == true {
                            cleanAlbum = extracted.album
                        }
                        didModify = true
                    } else {
                        didModify = true
                        continue
                    }
                }

                let id = UUID(uuidString: idStr) ?? UUID()
                loadedRules.append(PathHeuristicRule(
                    id: id,
                    pathPattern: patternStr,
                    targetArtist: cleanArtist,
                    targetAlbum: cleanAlbum,
                    matchCount: hitCount,
                    dateAdded: learnedAt
                ))
            }

            self.rules = loadedRules
            if didModify {
                save()
            }
        } catch {
            print("[PathHeuristicRuleStore] Failed to load rules from SQLite: \(error)")
        }
    }

    private func save() {
        do {
            try db.dbWriter.write { db in
                try db.execute(sql: "DELETE FROM path_heuristic_rules")
                for rule in self.rules {
                    try db.execute(
                        sql: """
                        INSERT OR REPLACE INTO path_heuristic_rules
                        (id, path_pattern, target_artist, target_album, confidence, learned_at, hit_count)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            rule.id.uuidString,
                            rule.pathPattern,
                            rule.targetArtist,
                            rule.targetAlbum,
                            1.0,
                            rule.dateAdded,
                            rule.matchCount
                        ]
                    )
                }
            }
            persistenceWriteCount += 1
        } catch {
            print("[PathHeuristicRuleStore] Failed to save rules to SQLite: \(error)")
        }
    }
}
