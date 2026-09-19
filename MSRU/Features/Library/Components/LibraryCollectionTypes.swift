//
//  LibraryCollectionTypes.swift
//  MSRU
//

import Foundation

// MARK: - View Mode

enum LibraryViewMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case table
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .table: return "Table"
        case .grid: return "Grid"
        }
    }

    var systemImage: String {
        switch self {
        case .table: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

// MARK: - Sort Field

enum LibrarySortField: String, CaseIterable, Identifiable, Codable, Sendable {
    case dateAdded
    case title
    case artist
    case album
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAdded: return "Date Added"
        case .title: return "Title"
        case .artist: return "Artist"
        case .album: return "Album"
        case .duration: return "Duration"
        }
    }
}

// MARK: - Collection Sorter & Filter

enum LibraryCollectionSortFilter {

    static func filterAndSort(
        tracks: [LibraryTrack],
        query: String,
        field: LibrarySortField,
        ascending: Bool
    ) -> [LibraryTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [LibraryTrack]
        if trimmed.isEmpty {
            filtered = tracks
        } else {
            let lower = trimmed.localizedLowercase
            filtered = tracks.filter { track in
                track.title.localizedCaseInsensitiveContains(lower) ||
                track.artist.localizedCaseInsensitiveContains(lower) ||
                (track.album?.localizedCaseInsensitiveContains(lower) ?? false)
            }
        }

        return filtered.sorted { a, b in
            let comparison: ComparisonResult
            switch field {
            case .title:
                comparison = a.title.localizedStandardCompare(b.title)
            case .artist:
                comparison = a.artist.localizedStandardCompare(b.artist)
            case .album:
                comparison = (a.album ?? "").localizedStandardCompare(b.album ?? "")
            case .duration:
                let durA = a.duration ?? 0
                let durB = b.duration ?? 0
                if durA == durB { comparison = .orderedSame }
                else if durA < durB { comparison = .orderedAscending }
                else { comparison = .orderedDescending }
            case .dateAdded:
                if a.dateAdded == b.dateAdded { comparison = .orderedSame }
                else if a.dateAdded < b.dateAdded { comparison = .orderedAscending }
                else { comparison = .orderedDescending }
            }

            if comparison == .orderedSame {
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            return ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }

    static func filterAndSort(
        tracks: [LocalTrack],
        query: String,
        field: LibrarySortField,
        ascending: Bool
    ) -> [LocalTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [LocalTrack]
        if trimmed.isEmpty {
            filtered = tracks
        } else {
            let lower = trimmed.localizedLowercase
            filtered = tracks.filter { track in
                track.title.localizedCaseInsensitiveContains(lower) ||
                track.artist.localizedCaseInsensitiveContains(lower) ||
                (track.album?.localizedCaseInsensitiveContains(lower) ?? false)
            }
        }

        return filtered.sorted { a, b in
            let comparison: ComparisonResult
            switch field {
            case .title:
                comparison = a.title.localizedStandardCompare(b.title)
            case .artist:
                comparison = a.artist.localizedStandardCompare(b.artist)
            case .album:
                comparison = (a.album ?? "").localizedStandardCompare(b.album ?? "")
            case .duration:
                if a.duration == b.duration { comparison = .orderedSame }
                else if a.duration < b.duration { comparison = .orderedAscending }
                else { comparison = .orderedDescending }
            case .dateAdded:
                comparison = a.title.localizedStandardCompare(b.title)
            }

            if comparison == .orderedSame {
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            return ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }
}
