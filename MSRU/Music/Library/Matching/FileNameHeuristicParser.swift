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

    // Precompiled static regular expressions
    private static let yearRegex = try? NSRegularExpression(pattern: #"[\(\[\{](\d{4})[\)\]\}]"#)
    private static let specRegexes: [NSRegularExpression] = [
        #"(?i)\[[^\]]*(FLAC|WAV|MP3|APE|DSD|AAC|AIFF|ALAC|Hi-Res|24bit|48khz|96khz|192khz|24-96|24-192|金碟|限量|头版)[^\]]*\]"#,
        #"(?i)\([^\)]*(WAV[/／\\]Cue|FLAC[/／\\]Cue|Cue|APE|FLAC|24K金碟|头版|限量|金碟)[^\)]*\)"#,
        #"(?i)\s*\[[^\]]*(FLAC|WAV|MP3|APE|DSD|AAC|AIFF|ALAC|Hi-Res|24bit|48khz|96khz|192khz|24-96|24-192|金碟|限量|头版)[^\]]*$"#,
        #"(?i)\s*\([^\)]*(WAV|FLAC|Cue|APE|24K金碟|头版|限量|金碟)[^\)]*$"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }
    private static let dashRegex = try? NSRegularExpression(pattern: #"\s*[–—－]\s*"#)
    private static let prefixRegex = try? NSRegularExpression(pattern: #"^(?:茶壶专辑|精选|华语|欧美|1\.歌曲)\s*-\s*"#)
    private static let trackRegex = try? NSRegularExpression(pattern: #"^(\d{1,3})[\s\.\-_]+\s*"#)

    /// Cleans and extracts structured clues (artist, album, year) from a folder name that may contain release specs or format tags.
    public static func parseFolderMetadata(_ folderName: String) -> (artist: String?, album: String?, year: Int?) {
        var working = folderName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Extract optional 4-digit year like (2020) or [2020]
        var detectedYear: Int? = nil
        if let match = yearRegex?.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)),
           let yearRange = Range(match.range(at: 1), in: working),
           let yearInt = Int(working[yearRange]),
           yearInt >= 1900 && yearInt <= 2099 {
            detectedYear = yearInt
            if let fullRange = Range(match.range, in: working) {
                working.removeSubrange(fullRange)
            }
        }

        // 2. Strip technical audio specs, format tags, and release descriptors
        for regex in specRegexes {
            working = regex.stringByReplacingMatches(
                in: working,
                range: NSRange(working.startIndex..., in: working),
                withTemplate: ""
            )
        }

        // 3. Normalize all unicode dashes to standard " - "
        if let regex = dashRegex {
            working = regex.stringByReplacingMatches(
                in: working,
                range: NSRange(working.startIndex..., in: working),
                withTemplate: " - "
            )
        }
        working = working.trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Strip generic categorization prefixes if present at beginning:
        // e.g. "茶壶专辑 - ", "精选 - ", "1.歌曲 - "
        if let regex = prefixRegex {
            working = regex.stringByReplacingMatches(
                in: working,
                range: NSRange(working.startIndex..., in: working),
                withTemplate: ""
            )
        }
        working = working.trimmingCharacters(in: .whitespacesAndNewlines)

        // 5. Split by " - "
        let parts = working.components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            let artist = parts[0]
            let album = parts[1]
            return (artist.isEmpty ? nil : artist, album.isEmpty ? nil : album, detectedYear)
        } else if parts.count == 1 {
            let single = parts[0]
            return (nil, single.isEmpty ? nil : single, detectedYear)
        }

        return (nil, nil, detectedYear)
    }

    /// Parses a file URL into candidate metadata clues, inspecting both filename and directory structure.
    public static func parse(fileURL: URL) -> ParsedFileNameCandidate {
        let candidate = parse(fileName: fileURL.lastPathComponent)

        // Check directory hierarchy for artist & album clues
        let components = fileURL.pathComponents
        let count = components.count
        var folderIndex = count - 2
        var parentFolder = components[folderIndex]

        let discOrFormat: Set<String> = [
            "cd1", "cd2", "cd3", "cd4", "cd 1", "cd 2", "cd 3", "cd 4",
            "disc 1", "disc 2", "disc 3", "disc 4", "disc1", "disc2",
            "flac", "wav", "ape", "mp3", "cue", "hires", "hi-res"
        ]

        let trimmedParent = parentFolder.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isDiscOrSubfolder = discOrFormat.contains(trimmedParent)
            || (trimmedParent.hasPrefix("cd") && trimmedParent.count <= 6)
            || (trimmedParent.hasPrefix("disc") && trimmedParent.count <= 8)
            || (!trimmedParent.contains("-") && (trimmedParent.hasSuffix("khz]") || trimmedParent.hasSuffix("bit]") || trimmedParent.hasSuffix("cue)")))

        if isDiscOrSubfolder && folderIndex > 1 {
            folderIndex -= 1
            parentFolder = components[folderIndex]
        }
        let grandparentFolder = folderIndex > 1 ? components[folderIndex - 1] : ""

        var finalArtist = candidate.artist
        var finalAlbum = candidate.album
        var finalYear = candidate.year

        // Known generic categorization folders
        let artistCategories: Set<String> = [
            "男歌手", "女歌手", "乐队", "组合", "歌手", "华语", "欧美", "日韩", "粤语", "纯音乐",
            "artists", "artist", "singers", "singer"
        ]
        let albumCategories: Set<String> = [
            "专辑", "albums", "album", "cd", "cds"
        ]

        let folderMeta = parseFolderMetadata(parentFolder)
        if finalYear == nil { finalYear = folderMeta.year }

        if artistCategories.contains(grandparentFolder.lowercased()) {
            if folderMeta.artist != nil && finalArtist == nil {
                finalArtist = folderMeta.artist
            } else if finalArtist == nil {
                finalArtist = parentFolder
            }
            if folderMeta.album != nil && finalAlbum == nil {
                finalAlbum = folderMeta.album
            }
        } else if albumCategories.contains(grandparentFolder.lowercased()) {
            if folderMeta.artist != nil && finalArtist == nil {
                finalArtist = folderMeta.artist
            }
            if finalAlbum == nil {
                finalAlbum = folderMeta.album ?? parentFolder
            }
        } else {
            if folderMeta.artist != nil && finalArtist == nil {
                finalArtist = folderMeta.artist
            }
            if folderMeta.album != nil && finalAlbum == nil {
                finalAlbum = folderMeta.album
            }
            if finalArtist == nil && !["music", "download", "downloads", "1.歌曲", "歌曲", "desktop", "documents", "audio"].contains(parentFolder.lowercased()) {
                finalArtist = folderMeta.album ?? parentFolder
            }
        }

        // Defensive fallback: if finalAlbum is still nil, fall back to folderMeta.album
        if finalAlbum == nil, let alb = folderMeta.album {
            finalAlbum = alb
        }
        if finalArtist == nil, let art = folderMeta.artist {
            finalArtist = art
        }

        return ParsedFileNameCandidate(
            trackNumber: candidate.trackNumber,
            artist: finalArtist,
            album: finalAlbum,
            title: candidate.title,
            year: finalYear,
            rawFileName: candidate.rawFileName
        )
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
