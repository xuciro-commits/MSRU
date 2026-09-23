//
//  PlaylistRuleEngine.swift
//  MSRU
//
//  Pure functional rule evaluation engine for Dynamic Smart Playlists.
//

import Foundation
import MusicDomain

// MARK: - Smart Playlist Rule Models

nonisolated public enum SmartPlaylistField: String, Codable, CaseIterable, Sendable {
    case title
    case artist
    case album
    case genre
    case isFavorite
    case isLossless
    case isHiRes
    case sampleRate
    case bitDepth
    case year
    case addedAt
    case playCount
    case duration
}

nonisolated public enum SmartPlaylistOperator: String, Codable, CaseIterable, Sendable {
    case contains
    case doesNotContain
    case equals
    case doesNotEqual
    case startsWith
    case endsWith
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case isTrue
    case isFalse
    case inLastNDays
}

nonisolated public enum SmartPlaylistValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case days(Int)

    private enum CodingKeys: String, CodingKey {
        case type, stringValue, numberValue, boolValue, daysValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "string":
            let val = try container.decode(String.self, forKey: .stringValue)
            self = .string(val)
        case "number":
            let val = try container.decode(Double.self, forKey: .numberValue)
            self = .number(val)
        case "boolean":
            let val = try container.decode(Bool.self, forKey: .boolValue)
            self = .boolean(val)
        case "days":
            let val = try container.decode(Int.self, forKey: .daysValue)
            self = .days(val)
        default:
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let val):
            try container.encode("string", forKey: .type)
            try container.encode(val, forKey: .stringValue)
        case .number(let val):
            try container.encode("number", forKey: .type)
            try container.encode(val, forKey: .numberValue)
        case .boolean(let val):
            try container.encode("boolean", forKey: .type)
            try container.encode(val, forKey: .boolValue)
        case .days(let val):
            try container.encode("days", forKey: .type)
            try container.encode(val, forKey: .daysValue)
        }
    }
}

nonisolated public struct SmartPlaylistRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var field: SmartPlaylistField
    public var op: SmartPlaylistOperator
    public var value: SmartPlaylistValue

    public init(
        id: UUID = UUID(),
        field: SmartPlaylistField,
        op: SmartPlaylistOperator,
        value: SmartPlaylistValue
    ) {
        self.id = id
        self.field = field
        self.op = op
        self.value = value
    }

    public func matches(track: TrackEvaluationContext, referenceDate: Date = Date()) -> Bool {
        switch field {
        case .title:
            return evaluateString(track.title)
        case .artist:
            return evaluateString(track.artist)
        case .album:
            return evaluateString(track.album)
        case .genre:
            return evaluateString(track.genre)
        case .isFavorite:
            return evaluateBool(track.isFavorite)
        case .isLossless:
            return evaluateBool(track.isLossless)
        case .isHiRes:
            return evaluateBool(track.isHiRes)
        case .sampleRate:
            return evaluateNumber(track.sampleRate)
        case .bitDepth:
            return evaluateNumber(Double(track.bitDepth))
        case .year:
            guard let year = track.year else { return false }
            return evaluateNumber(Double(year))
        case .playCount:
            return evaluateNumber(Double(track.playCount))
        case .duration:
            return evaluateNumber(track.duration)
        case .addedAt:
            return evaluateDate(track.addedAt, referenceDate: referenceDate)
        }
    }

    private func evaluateString(_ text: String) -> Bool {
        guard case .string(let target) = value else { return false }
        let a = text.lowercased()
        let b = target.lowercased()
        switch op {
        case .contains:
            return a.contains(b)
        case .doesNotContain:
            return !a.contains(b)
        case .equals:
            return a == b
        case .doesNotEqual:
            return a != b
        case .startsWith:
            return a.hasPrefix(b)
        case .endsWith:
            return a.hasSuffix(b)
        default:
            return false
        }
    }

    private func evaluateBool(_ boolValue: Bool) -> Bool {
        switch op {
        case .isTrue:
            return boolValue == true
        case .isFalse:
            return boolValue == false
        case .equals:
            if case .boolean(let target) = value {
                return boolValue == target
            }
            return false
        default:
            return false
        }
    }

    private func evaluateNumber(_ number: Double) -> Bool {
        guard case .number(let target) = value else { return false }
        switch op {
        case .equals:
            return abs(number - target) < 0.001
        case .doesNotEqual:
            return abs(number - target) >= 0.001
        case .greaterThan:
            return number > target
        case .greaterThanOrEqual:
            return number >= target
        case .lessThan:
            return number < target
        case .lessThanOrEqual:
            return number <= target
        default:
            return false
        }
    }

    private func evaluateDate(_ date: Date, referenceDate: Date) -> Bool {
        switch op {
        case .inLastNDays:
            if case .days(let days) = value {
                let cutoff = referenceDate.addingTimeInterval(-Double(days * 86400))
                return date >= cutoff && date <= referenceDate
            }
            return false
        default:
            return false
        }
    }
}

nonisolated public enum SmartPlaylistMatchMode: String, Codable, CaseIterable, Sendable {
    case all
    case any
}

nonisolated public enum SmartPlaylistSortOrder: String, Codable, CaseIterable, Sendable {
    case titleAscending
    case artistAscending
    case dateAddedDescending
    case playCountDescending
    case durationDescending
}

nonisolated public struct SmartPlaylistRuleGroup: Codable, Hashable, Sendable {
    public var matchMode: SmartPlaylistMatchMode
    public var rules: [SmartPlaylistRule]
    public var limit: Int?
    public var sortBy: SmartPlaylistSortOrder?

    public init(
        matchMode: SmartPlaylistMatchMode = .all,
        rules: [SmartPlaylistRule] = [],
        limit: Int? = nil,
        sortBy: SmartPlaylistSortOrder? = nil
    ) {
        self.matchMode = matchMode
        self.rules = rules
        self.limit = limit
        self.sortBy = sortBy
    }
}

// MARK: - Track Evaluation Context

nonisolated public struct TrackEvaluationContext: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let genre: String
    public let isFavorite: Bool
    public let isLossless: Bool
    public let isHiRes: Bool
    public let sampleRate: Double
    public let bitDepth: Int
    public let year: Int?
    public let addedAt: Date
    public let playCount: Int
    public let duration: TimeInterval

    public init(
        id: String,
        title: String,
        artist: String,
        album: String,
        genre: String = "",
        isFavorite: Bool = false,
        isLossless: Bool = false,
        isHiRes: Bool = false,
        sampleRate: Double = 44100.0,
        bitDepth: Int = 16,
        year: Int? = nil,
        addedAt: Date = Date(),
        playCount: Int = 0,
        duration: TimeInterval = 0.0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.isFavorite = isFavorite
        self.isLossless = isLossless
        self.isHiRes = isHiRes
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.year = year
        self.addedAt = addedAt
        self.playCount = playCount
        self.duration = duration
    }

    public init(_ track: LocalTrack, isFavorite: Bool = false, playCount: Int = 0,
                includeAddedAt: Bool = true) {
        let ext = track.fileURL.pathExtension.uppercased()
        let losslessExts = ["FLAC", "WAV", "AIFF", "AIF", "ALAC", "DTS", "DSF", "DSD"]
        let isLossless = losslessExts.contains(ext)
        let isHiRes = ext == "DSF" || ext == "DSD" || (isLossless && (ext == "FLAC" || ext == "WAV"))

        let fileAddedDate: Date = {
            guard includeAddedAt else { return Date() }
            if let values = try? track.fileURL.resourceValues(forKeys: [.creationDateKey]),
               let date = values.creationDate {
                return date
            }
            return Date()
        }()

        self.init(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? "",
            genre: "",
            isFavorite: isFavorite,
            isLossless: isLossless,
            isHiRes: isHiRes,
            sampleRate: isHiRes ? 96000.0 : 44100.0,
            bitDepth: isLossless ? 24 : 16,
            year: track.year,
            addedAt: fileAddedDate,
            playCount: playCount,
            duration: track.duration
        )
    }

}

// MARK: - Functional Rule Engine

nonisolated public struct PlaylistRuleEngine: Sendable {

    public static func evaluate(
        rules: SmartPlaylistRuleGroup,
        tracks: [TrackEvaluationContext],
        referenceDate: Date = Date()
    ) -> [TrackEvaluationContext] {
        guard !rules.rules.isEmpty else {
            return applyLimitAndSort(tracks: tracks, rules: rules)
        }

        let filtered = tracks.filter { matches(rules: rules, track: $0, referenceDate: referenceDate) }

        return applyLimitAndSort(tracks: filtered, rules: rules)
    }

    public static func matches(
        rules: SmartPlaylistRuleGroup,
        track: TrackEvaluationContext,
        referenceDate: Date = Date()
    ) -> Bool {
        guard !rules.rules.isEmpty else { return true }
        switch rules.matchMode {
        case .all:
            return rules.rules.allSatisfy { $0.matches(track: track, referenceDate: referenceDate) }
        case .any:
            return rules.rules.contains { $0.matches(track: track, referenceDate: referenceDate) }
        }
    }

    public static func evaluate(
        rules: SmartPlaylistRuleGroup,
        tracks: [LocalTrack],
        favorites: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [LocalTrack] {
        let needsAddedAt = rules.rules.contains { $0.field == .addedAt }
            || rules.sortBy == .dateAddedDescending
        let contexts = tracks.map {
            TrackEvaluationContext($0, isFavorite: favorites.contains($0.id),
                                   includeAddedAt: needsAddedAt)
        }
        let evaluated = evaluate(rules: rules, tracks: contexts, referenceDate: referenceDate)
        let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return evaluated.compactMap { trackMap[$0.id] }
    }

    private static func applyLimitAndSort(
        tracks: [TrackEvaluationContext],
        rules: SmartPlaylistRuleGroup
    ) -> [TrackEvaluationContext] {
        var sortedTracks = tracks
        if let sortBy = rules.sortBy {
            switch sortBy {
            case .titleAscending:
                sortedTracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .artistAscending:
                sortedTracks.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
            case .dateAddedDescending:
                sortedTracks.sort { $0.addedAt > $1.addedAt }
            case .playCountDescending:
                sortedTracks.sort { $0.playCount > $1.playCount }
            case .durationDescending:
                sortedTracks.sort { $0.duration > $1.duration }
            }
        }

        if let limit = rules.limit, limit > 0 {
            return Array(sortedTracks.prefix(limit))
        }

        return sortedTracks
    }

    // MARK: - Presets

    public struct Presets {
        public static func favorites() -> SmartPlaylistRuleGroup {
            SmartPlaylistRuleGroup(
                matchMode: .all,
                rules: [
                    SmartPlaylistRule(field: .isFavorite, op: .isTrue, value: .boolean(true))
                ],
                sortBy: .dateAddedDescending
            )
        }

        public static func recentlyAdded(days: Int = 30) -> SmartPlaylistRuleGroup {
            SmartPlaylistRuleGroup(
                matchMode: .all,
                rules: [
                    SmartPlaylistRule(field: .addedAt, op: .inLastNDays, value: .days(days))
                ],
                sortBy: .dateAddedDescending
            )
        }

        public static func hiResAudio() -> SmartPlaylistRuleGroup {
            SmartPlaylistRuleGroup(
                matchMode: .all,
                rules: [
                    SmartPlaylistRule(field: .isHiRes, op: .isTrue, value: .boolean(true))
                ],
                sortBy: .artistAscending
            )
        }

        public static func losslessMasters() -> SmartPlaylistRuleGroup {
            SmartPlaylistRuleGroup(
                matchMode: .all,
                rules: [
                    SmartPlaylistRule(field: .isLossless, op: .isTrue, value: .boolean(true))
                ],
                sortBy: .artistAscending
            )
        }

        nonisolated public init() {}
    }
}
