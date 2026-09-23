import Foundation
import AVFoundation

/// Local media I/O boundary. UI state and selection remain in the store/scene.
protocol LocalLibraryRepository: Sendable {
    func loadTracks() async throws -> [LocalTrack]
    func fetchPage(_ request: LocalTrackPageRequest) async throws -> LocalTrackPage
    func importTrack(from url: URL) async throws -> LocalTrack?
    func importTracks(from urls: [URL]) async throws -> [LocalTrack]
    func saveTrackInPlace(_ track: LocalTrack) async throws
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws
    func readTrack(from url: URL) async throws -> LocalTrack
}

nonisolated struct LocalTrackPageRequest: Sendable {
    enum Sort: String, Sendable {
        case dateAdded, title, artist, album, duration
    }
    let query: String
    let sort: Sort
    let ascending: Bool
    let offset: Int
    let limit: Int

    init(query: String = "", sort: Sort = .title, ascending: Bool = true,
         offset: Int = 0, limit: Int = 128) {
        self.query = query
        self.sort = sort
        self.ascending = ascending
        self.offset = max(0, offset)
        self.limit = min(max(1, limit), 512)
    }
}

nonisolated struct LocalTrackPage: Sendable {
    let tracks: [LocalTrack]
    let totalCount: Int
    let offset: Int
    var hasMore: Bool { offset + tracks.count < totalCount }
}

extension LocalLibraryRepository {
    func fetchPage(_ request: LocalTrackPageRequest) async throws -> LocalTrackPage {
        let all = try await loadTracks()
        let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = all.filter { track in
            query.isEmpty || track.title.localizedCaseInsensitiveContains(query)
                || track.artist.localizedCaseInsensitiveContains(query)
                || (track.album?.localizedCaseInsensitiveContains(query) ?? false)
        }
        let sorted = filtered.sorted { lhs, rhs in
            let first: String
            let second: String
            switch request.sort {
            case .artist: first = lhs.artist; second = rhs.artist
            case .album: first = lhs.album ?? ""; second = rhs.album ?? ""
            default: first = lhs.title; second = rhs.title
            }
            let result = first.localizedStandardCompare(second)
            return request.ascending ? result == .orderedAscending : result == .orderedDescending
        }
        let page = request.offset < sorted.count
            ? Array(sorted[request.offset..<min(sorted.count, request.offset + request.limit)]) : []
        return LocalTrackPage(tracks: page, totalCount: sorted.count, offset: request.offset)
    }
    func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {}
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws {
        try await saveTracksInPlace(tracks)
    }
    func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        var imported: [LocalTrack] = []
        for url in urls {
            if let track = try await importTrack(from: url) {
                imported.append(track)
            }
        }
        return imported
    }
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {}
    func readTrack(from url: URL) async throws -> LocalTrack {
        try await SQLiteLocalLibraryRepository.readTrack(from: url)
    }
}

typealias FileLocalLibraryRepository = SQLiteLocalLibraryRepository
