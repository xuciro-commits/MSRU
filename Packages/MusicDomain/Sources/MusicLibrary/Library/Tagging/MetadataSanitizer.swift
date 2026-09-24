//
//  MetadataSanitizer.swift
//  MSRU
//
//  Created for Library Hygiene and Anomaly Detection.
//

import Foundation
import MusicDomain

/// Holds sanitized metadata results and anomaly markers.
nonisolated public struct CleanedTrackInfo: Sendable, Equatable {
    public let cleanTitle: String
    public let cleanArtist: String
    public let cleanAlbum: String?
    public let trackNumber: Int?
    public let isAnomalous: Bool

    public init(
        cleanTitle: String,
        cleanArtist: String,
        cleanAlbum: String?,
        trackNumber: Int?,
        isAnomalous: Bool
    ) {
        self.cleanTitle = cleanTitle
        self.cleanArtist = cleanArtist
        self.cleanAlbum = cleanAlbum
        self.trackNumber = trackNumber
        self.isAnomalous = isAnomalous
    }
}

/// Central sanitization and anomaly detection engine for music metadata.
nonisolated public enum MetadataSanitizer {

    // MARK: - Full Sanitization

    public static func sanitize(
        title: String,
        artist: String,
        album: String?,
        trackNumber: Int? = nil
    ) -> CleanedTrackInfo {
        let cleanedArt = cleanArtistName(artist)
        let (titleAfterClean, detectedTrackNo, isTitleAnomalous) = cleanTrackTitle(title, artist: cleanedArt)

        var finalTrackNo = trackNumber
        if finalTrackNo == nil || finalTrackNo == 0 {
            finalTrackNo = detectedTrackNo
        }

        var cleanedAlb: String? = nil
        if let rawAlb = album, !rawAlb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let processedAlb = cleanAlbumTitle(rawAlb, artist: cleanedArt)
            if !processedAlb.isEmpty && !FileNameHeuristicParser.isGenericFolderName(processedAlb) {
                // Safety check: album cannot equal artist
                if processedAlb.lowercased() != cleanedArt.lowercased() {
                    cleanedAlb = processedAlb
                }
            }
        }

        let isAlbumAnom = isAnomalousAlbum(cleanedAlb, artist: cleanedArt)
        let isAnom = isTitleAnomalous || isAlbumAnom

        return CleanedTrackInfo(
            cleanTitle: titleAfterClean,
            cleanArtist: cleanedArt.isEmpty ? "Unknown Artist" : cleanedArt,
            cleanAlbum: cleanedAlb,
            trackNumber: finalTrackNo,
            isAnomalous: isAnom
        )
    }

    // MARK: - Title Sanitization

    public static func cleanTrackTitle(
        _ rawTitle: String,
        artist: String? = nil
    ) -> (title: String, trackNumber: Int?, isAnomalous: Bool) {
        var str = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Detect placeholder titles like Track01, Track 05, AudioTrack 02, CD Track 1
        if isAnomalousTitle(str) {
            let trackNum = extractTrackNumber(from: str)
            return (str, trackNum, true)
        }

        var detectedTrackNo: Int? = nil

        // 2. Strip leading track number: e.g. "01. 太阳雨", "02-红豆", "03 恰似你的温柔"
        let trackPrefixPattern = #"^\s*(\d{1,3})[\.\-\s_]+(.*)$"#
        if let regex = try? NSRegularExpression(pattern: trackPrefixPattern) {
            let nsStr = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: nsStr.length))
            if let match = matches.first, match.numberOfRanges >= 3 {
                let numStr = nsStr.substring(with: match.range(at: 1))
                let titlePart = nsStr.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !titlePart.isEmpty {
                    detectedTrackNo = Int(numStr)
                    str = titlePart
                }
            }
        }

        // 3. Strip leading artist prefix: e.g. "李克勤 - 一生不变" -> "一生不变"
        if let artist, !artist.isEmpty {
            let cleanArt = cleanArtistName(artist)
            if !cleanArt.isEmpty && str.lowercased().hasPrefix(cleanArt.lowercased()) {
                let stripped = str.dropFirst(cleanArt.count).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_"))
                if !stripped.isEmpty {
                    str = String(stripped)
                }
            }
        }

        // Check if remaining string has "Artist - Title" format
        if str.contains(" - ") {
            let parts = str.components(separatedBy: " - ")
            if parts.count == 2, !parts[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                str = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Re-check after stripping prefixes
        let isAnomAfter = isAnomalousTitle(str)
        return (str, detectedTrackNo, isAnomAfter)
    }

    // MARK: - Album Sanitization

    public static func cleanAlbumTitle(_ rawAlbum: String, artist: String? = nil) -> String {
        var str = rawAlbum.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Remove format noise brackets: [SACD], [DSD], [16-44.1], [qobuz], [24bit], [WAV+CUE]
        let formatPattern = #"(?i)\[(sacd|dsd|dsf|flac|wav|ape|wv|mqa|hi-res|qobuz|tidal|24bit|16bit|16-44\.1|24-96|24-192|dts|dts\s*6\.1|wav\+cue|flac\+cue|hqcd|hqcdii|lpcd|xrpk|uhqcd|shm-cd|dxd|bs-cd|首版|限量版|纯银cd|纯银|金碟|黑胶).*?\]"#
        str = str.replacingOccurrences(of: formatPattern, with: "", options: .regularExpression)

        let formatParenPattern = #"(?i)\((sacd|dsd|dsf|flac|wav|ape|wv|mqa|hi-res|qobuz|tidal|24bit|16bit|16-44\.1|24-96|24-192|dts|dts\s*6\.1|wav\+cue|flac\+cue).*?\)"#
        str = str.replacingOccurrences(of: formatParenPattern, with: "", options: .regularExpression)

        // 2. Remove Chinese edition brackets: 【无损】, 【FLAC】, 【车载】
        let chineseBracketsPattern = #"【(无损|flac|wav|车载|高音质).*?】"#
        str = str.replacingOccurrences(of: chineseBracketsPattern, with: "", options: .regularExpression)

        // 3. Remove leading year brackets: e.g. "[2016] 陈果 - 幻影" -> "陈果 - 幻影"
        str = str.replacingOccurrences(of: #"^\s*\[\d{4}\]\s*"#, with: "", options: .regularExpression)

        // 4. Strip artist name prefix if album was named "Artist - Album" or "Artist Album"
        if let artist, !artist.isEmpty {
            let cleanArt = cleanArtistName(artist)
            if !cleanArt.isEmpty && str.lowercased().hasPrefix(cleanArt.lowercased()) {
                let stripped = str.dropFirst(cleanArt.count).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_"))
                if !stripped.isEmpty {
                    str = String(stripped)
                }
            }
        }

        // 5. Strip trailing rip/dts tags: e.g. "DTS6.1 1", "DTS 1"
        str = str.replacingOccurrences(of: #"(?i)(dts\s*6\.1|dts|wav|flac)\s*\d*$"#, with: "", options: .regularExpression)

        str = str.trimmingCharacters(in: CharacterSet(charactersIn: " -–—_[]()【】 "))
        return str.isEmpty ? rawAlbum : str
    }

    // MARK: - Artist Sanitization

    public static func cleanArtistName(_ rawArtist: String) -> String {
        var str = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Remove leading web scraper tags: e.g. "[51ape.com]郑源" -> "郑源"
        str = str.replacingOccurrences(of: #"^\s*\[[a-zA-Z0-9\.\-_]+\]\s*"#, with: "", options: .regularExpression)

        // 2. Remove trailing brackets or edition tags: e.g. "刘文正.流金三十年][6N纯银" -> "刘文正"
        str = str.replacingOccurrences(of: #"\]\[.*$"#, with: "", options: .regularExpression)

        // 3. Disambiguate if artist contains period followed by album: e.g. "刘文正.流金三十年"
        if str.contains(".") && !str.contains(" ") && str.count > 6 {
            let parts = str.components(separatedBy: ".")
            if let first = parts.first, first.count >= 2 {
                str = first
            }
        }

        str = str.trimmingCharacters(in: CharacterSet(charactersIn: " -–—_[]() "))
        return str.isEmpty ? rawArtist : str
    }

    // MARK: - Anomaly Detectors

    public static func isAnomalousTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        // Track01, Track 05, AudioTrack 02, CD Track 1, Track_03
        let pattern = #"^(?i)(track|audiotrack|audio track|cd track|track_)[\s_]*\d+$"#
        if trimmed.range(of: pattern, options: .regularExpression) != nil {
            return true
        }

        // Pure numbers: "01", "12"
        if trimmed.allSatisfy({ $0.isNumber }) {
            return true
        }

        return false
    }

    public static func isAnomalousAlbum(_ album: String?, artist: String) -> Bool {
        guard let alb = album?.trimmingCharacters(in: .whitespacesAndNewlines), !alb.isEmpty else {
            return true
        }
        if FileNameHeuristicParser.isGenericFolderName(alb) {
            return true
        }
        if alb.lowercased() == artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return true
        }
        return false
    }

    public static func extractTrackNumber(from title: String) -> Int? {
        let digits = title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits)
    }
}
