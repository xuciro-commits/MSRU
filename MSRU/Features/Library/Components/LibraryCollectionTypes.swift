//
//  LibraryCollectionTypes.swift
//  MSRU
//

import Foundation
import MusicLibrary

// MARK: - View Mode

enum LibraryViewMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case table
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .table: return "List"
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

    /// Filters and sorts an in-memory track list. `tracks` must be newest
    /// first; date sorting keeps (or reverses) that order.
    static func filterAndSort(
        tracks: [LocalTrack],
        query: String,
        field: LibrarySortField,
        ascending: Bool
    ) -> [LocalTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty ? tracks : tracks.filter { track in
            track.title.localizedCaseInsensitiveContains(trimmed) ||
            track.artist.localizedCaseInsensitiveContains(trimmed) ||
            (track.album?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
        let ordered: [LocalTrack]
        switch field {
        case .dateAdded:
            return ascending ? filtered.reversed() : filtered
        case .title:
            ordered = filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist:
            ordered = filtered.sorted { $0.artist.localizedStandardCompare($1.artist) == .orderedAscending }
        case .album:
            ordered = filtered.sorted { ($0.album ?? "").localizedStandardCompare($1.album ?? "") == .orderedAscending }
        case .duration:
            ordered = filtered.sorted { $0.duration < $1.duration }
        }
        return ascending ? ordered : ordered.reversed()
    }
}
