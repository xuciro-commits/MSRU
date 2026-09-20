//
//  PathHeuristicRuleStore.swift
//  MSRU
//
//  Created for Directory Path Heuristics & Local Rule Learning.
//

import Foundation
import Observation

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
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Rules", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("path_heuristic_rules.json")
        }
        load()
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
    public func addRule(pathPattern: String, targetArtist: String, targetAlbum: String? = nil) {
        let cleanPattern = pathPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = targetArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPattern.isEmpty, !cleanArtist.isEmpty, cleanArtist != "Unknown Artist" else { return }
        guard !Self.genericFolderNames.contains(cleanPattern.lowercased()) else { return }

        if let idx = rules.firstIndex(where: { $0.pathPattern.lowercased() == cleanPattern.lowercased() }) {
            rules[idx].targetArtist = cleanArtist
            rules[idx].targetAlbum = targetAlbum
        } else {
            rules.append(PathHeuristicRule(
                pathPattern: cleanPattern,
                targetArtist: cleanArtist,
                targetAlbum: targetAlbum
            ))
        }
        save()
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
    public func learnFrom(folderURL: URL?, artist: String, album: String? = nil) {
        guard let folderURL else { return }
        let folderName = folderURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderName.isEmpty, folderName != "/" else { return }
        guard !Self.genericFolderNames.contains(folderName.lowercased()) else { return }

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
                return
            }
        }

        addRule(pathPattern: folderName, targetArtist: finalArtist, targetAlbum: finalAlbum)
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

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PathHeuristicRule].self, from: data) else {
            return
        }

        var repaired: [PathHeuristicRule] = []
        var didModify = false

        for var rule in decoded {
            let pattern = rule.pathPattern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.genericFolderNames.contains(pattern) {
                didModify = true
                continue
            }
            let cleanArtist = rule.targetArtist.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanArtist.isEmpty || cleanArtist == "Unknown Artist" {
                // Auto-repair if pattern has "Artist - Album"
                if let extracted = Self.extractArtistAndAlbum(from: rule.pathPattern) {
                    rule.targetArtist = extracted.artist
                    if rule.targetAlbum == nil {
                        rule.targetAlbum = extracted.album
                    }
                    repaired.append(rule)
                    didModify = true
                } else {
                    // Drop invalid Unknown Artist rule
                    didModify = true
                }
            } else {
                repaired.append(rule)
            }
        }

        self.rules = repaired
        if didModify {
            save()
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(rules) else { return }
        try? encoded.write(to: storageURL, options: .atomic)
    }
}
