//
//  LrcLyrics.swift
//  AppFoundation
//
//  Created for Standard Synchronized LRC Lyrics Parsing & Real-Time Sync.
//

import Foundation

/// A single timestamped line of lyrics.
public struct LrcLine: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let text: String

    public init(id: UUID = UUID(), timestamp: TimeInterval, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}

/// A parsed LRC document containing metadata and timed lines.
public struct LrcDocument: Sendable, Equatable, Codable {
    public var metadata: [String: String]
    public var lines: [LrcLine]
    public var plainText: String

    public var isSynced: Bool {
        !lines.isEmpty
    }

    public init(metadata: [String: String] = [:], lines: [LrcLine] = [], plainText: String = "") {
        self.metadata = metadata
        self.lines = lines
        self.plainText = plainText
    }

    /// Finds the index of the line active at the given playback time.
    public func activeLineIndex(at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        // The active line is the last line with timestamp <= time
        var activeIndex: Int? = nil
        for (idx, line) in lines.enumerated() {
            if line.timestamp <= time {
                activeIndex = idx
            } else {
                break
            }
        }
        return activeIndex
    }
}

/// Robust parser for standard and extended LRC files.
public struct LrcParser: Sendable {
    public init() {}

    /// Parses an LRC formatted string into an `LrcDocument`.
    public static func parse(_ text: String) -> LrcDocument {
        var metadata: [String: String] = [:]
        var parsedLines: [LrcLine] = []
        var plainLines: [String] = []

        let rawLines = text.components(separatedBy: .newlines)

        // Regex for [mm:ss.xx] or [mm:ss:xx] or [mm:ss]
        // Can appear multiple times at start of line: [00:12.34][00:45.67]Hello
        let timestampPattern = #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
        let metaPattern = #"^\[([a-zA-Z]+):(.*)\]$"#

        guard let timestampRegex = try? NSRegularExpression(pattern: timestampPattern),
              let metaRegex = try? NSRegularExpression(pattern: metaPattern) else {
            return LrcDocument(plainText: text)
        }

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let nsLine = trimmed as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            // Check if it's a metadata tag like [ar:Artist]
            if let metaMatch = metaRegex.firstMatch(in: trimmed, range: fullRange) {
                let key = nsLine.substring(with: metaMatch.range(at: 1)).lowercased()
                let value = nsLine.substring(with: metaMatch.range(at: 2)).trimmingCharacters(in: .whitespaces)
                metadata[key] = value
                continue
            }

            // Find all timestamps on this line
            let matches = timestampRegex.matches(in: trimmed, range: fullRange)
            if matches.isEmpty {
                // Untimed line
                plainLines.append(trimmed)
                continue
            }

            // Text starts after the last timestamp match
            let lastMatch = matches[matches.count - 1]
            let textStartIndex = lastMatch.range.location + lastMatch.range.length
            let lyricsText = textStartIndex < nsLine.length
                ? nsLine.substring(from: textStartIndex).trimmingCharacters(in: .whitespaces)
                : ""

            plainLines.append(lyricsText)

            for match in matches {
                guard let minStr = Range(match.range(at: 1), in: trimmed).map({ String(trimmed[$0]) }),
                      let secStr = Range(match.range(at: 2), in: trimmed).map({ String(trimmed[$0]) }),
                      let min = Double(minStr),
                      let sec = Double(secStr) else {
                    continue
                }

                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound,
                   let fracStr = Range(match.range(at: 3), in: trimmed).map({ String(trimmed[$0]) }) {
                    if let fracVal = Double(fracStr) {
                        // If 2 digits, hundredths of second; if 3 digits, milliseconds
                        fraction = fracStr.count == 3 ? fracVal / 1000.0 : fracVal / 100.0
                    }
                }

                let time = min * 60.0 + sec + fraction
                parsedLines.append(LrcLine(timestamp: time, text: lyricsText))
            }
        }

        // Apply offset tag if present (e.g. [offset:+500] in milliseconds)
        if let offsetStr = metadata["offset"], let offsetMs = Double(offsetStr) {
            let offsetSec = offsetMs / 1000.0
            parsedLines = parsedLines.map {
                LrcLine(id: $0.id, timestamp: max(0, $0.timestamp + offsetSec), text: $0.text)
            }
        }

        // Sort lines chronologically
        parsedLines.sort { $0.timestamp < $1.timestamp }

        let plainText = plainLines.joined(separator: "\n")
        return LrcDocument(metadata: metadata, lines: parsedLines, plainText: plainText)
    }
}
