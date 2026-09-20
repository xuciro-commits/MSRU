//
//  FileNameHeuristicParser.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation

/// Structured metadata candidate extracted from a raw audio filename.
nonisolated public struct ParsedFileNameCandidate: Sendable, Equatable, Codable {
    public let trackNumber: Int?
    public let artist: String?
    public let album: String?
    public let title: String
    public let year: Int?
    public let rawFileName: String

    public init(
        trackNumber: Int? = nil,
        artist: String? = nil,
        album: String? = nil,
        title: String,
        year: Int? = nil,
        rawFileName: String
    ) {
        self.trackNumber = trackNumber
        self.artist = artist
        self.album = album
        self.title = title
        self.year = year
        self.rawFileName = rawFileName
    }
}

/// Deterministic heuristic parser for disorganized or raw audio filenames.
///
/// Converts messy filenames into structured metadata clues without hallucination.
nonisolated public enum FileNameHeuristicParser {

    /// Parses a file URL into candidate metadata clues.
    public static func parse(fileURL: URL) -> ParsedFileNameCandidate {
        parse(fileName: fileURL.lastPathComponent)
    }

    /// Parses a filename string (with or without extension) into structured metadata clues.
    public static func parse(fileName: String) -> ParsedFileNameCandidate {
        // Strip file extension
        let baseName: String
        if let dotIndex = fileName.lastIndex(of: "."), dotIndex != fileName.startIndex {
            baseName = String(fileName[..<dotIndex])
        } else {
            baseName = fileName
        }

        var working = baseName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Extract optional year like (2003) or [2020]
        var detectedYear: Int? = nil
        let yearRegex = try? NSRegularExpression(pattern: #"[\(\[\{](\d{4})[\)\]\}]"#)
        if let match = yearRegex?.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)) {
            if let yearRange = Range(match.range(at: 1), in: working), let yearInt = Int(working[yearRange]) {
                if yearInt >= 1900 && yearInt <= 2099 {
                    detectedYear = yearInt
                    if let fullRange = Range(match.range, in: working) {
                        working.removeSubrange(fullRange)
                        working = working.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        // 2. Extract leading track number like "04 ", "04 - ", "04. ", "04_"
        var detectedTrack: Int? = nil
        let trackRegex = try? NSRegularExpression(pattern: #"^(\d{1,3})[\s\.\-_]+\s*"#)
        if let match = trackRegex?.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)) {
            if let numRange = Range(match.range(at: 1), in: working), let num = Int(working[numRange]) {
                detectedTrack = num
                if let fullRange = Range(match.range, in: working) {
                    working.removeSubrange(fullRange)
                    working = working.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // 3. Split by standard delimiter hyphens: " - " or " _ "
        let parts = working.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var detectedArtist: String? = nil
        var detectedAlbum: String? = nil
        var detectedTitle: String = working

        if parts.count == 3 {
            // Pattern: Artist - Album - Title
            detectedArtist = parts[0]
            detectedAlbum = parts[1]
            detectedTitle = parts[2]
        } else if parts.count == 2 {
            // Pattern: Artist - Title
            detectedArtist = parts[0]
            detectedTitle = parts[1]
        } else {
            // Single chunk
            detectedTitle = working
        }

        // Secondary track check inside title (e.g. if title is "04. 晴天")
        if detectedTrack == nil {
            if let match = trackRegex?.firstMatch(in: detectedTitle, range: NSRange(detectedTitle.startIndex..., in: detectedTitle)) {
                if let numRange = Range(match.range(at: 1), in: detectedTitle), let num = Int(detectedTitle[numRange]) {
                    detectedTrack = num
                    if let fullRange = Range(match.range, in: detectedTitle) {
                        detectedTitle.removeSubrange(fullRange)
                        detectedTitle = detectedTitle.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        if detectedTitle.isEmpty {
            detectedTitle = baseName
        }

        return ParsedFileNameCandidate(
            trackNumber: detectedTrack,
            artist: detectedArtist,
            album: detectedAlbum,
            title: detectedTitle,
            year: detectedYear,
            rawFileName: fileName
        )
    }
}
