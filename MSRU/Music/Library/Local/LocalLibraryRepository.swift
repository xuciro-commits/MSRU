import Foundation
import AVFoundation

/// Local media I/O boundary. UI state and selection remain in the store/scene.
protocol LocalLibraryRepository: Sendable {
    func loadTracks() async throws -> [LocalTrack]
    func fetchPage(_ request: LocalTrackPageRequest) async throws -> LocalTrackPage
    func fetchTracks(withIDs ids: Set<String>) async throws -> [LocalTrack]
    func fetchTracks(forReleaseIDs ids: Set<String>) async throws -> [LocalTrack]
    func fetchTracks(forArtistIDs ids: Set<String>) async throws -> [LocalTrack]
    func fetchTracks(inFolder folder: URL) async throws -> [LocalTrack]
    func fetchTracks(withFilenames names: Set<String>) async throws -> [LocalTrack]
    func fetchTracks(matchingAlbum title: String, artist: String) async throws -> [LocalTrack]
    func fetchTracks(matchingArtist name: String) async throws -> [LocalTrack]
    func fetchMaintenancePage(afterPath: String?, limit: Int) async throws -> LocalMaintenancePage
    func findUniqueTrack(title: String, artist: String?) async throws -> LocalTrack?
    func searchTracks(_ query: String, limit: Int) async throws -> [LocalTrack]
    func importTrack(from url: URL) async throws -> LocalTrack?
    func importTracks(from urls: [URL]) async throws -> [LocalTrack]
    func importTracksDetailed(from urls: [URL]) async throws -> LocalImportResult
    func saveTrackInPlace(_ track: LocalTrack) async throws
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws
    func readTrack(from url: URL) async throws -> LocalTrack
}

nonisolated struct LocalImportFailure: Sendable {
    let fileURL: URL
    let reason: String
}

nonisolated struct LocalImportResult: Sendable {
    let tracks: [LocalTrack]
    let failures: [LocalImportFailure]
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

nonisolated struct LocalMaintenancePage: Sendable {
    let tracks: [LocalTrack]
    let nextPath: String?
}

extension LocalLibraryRepository {
    func fetchTracks(withIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter {
            ids.contains($0.id) || ids.contains($0.fileURL.path)
                || ids.contains($0.fileURL.standardizedFileURL.path)
        }
    }
    func fetchTracks(forReleaseIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter { track in
            guard let album = track.album else { return false }
            return ids.contains(DeterministicID.release(artist: track.artist, title: album).rawValue)
        }
    }
    func fetchTracks(forArtistIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter {
            ids.contains(DeterministicID.artist(name: $0.artist).rawValue)
        }
    }
    func fetchTracks(inFolder folder: URL) async throws -> [LocalTrack] {
        let prefix = folder.standardizedFileURL.path
        return try await loadTracks().filter {
            let path = $0.fileURL.standardizedFileURL.path
            return path == prefix || path.hasPrefix(prefix + "/")
        }
    }
    func fetchTracks(withFilenames names: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter { names.contains($0.fileURL.lastPathComponent) }
    }
    func fetchTracks(matchingAlbum title: String, artist: String) async throws -> [LocalTrack] {
        try await loadTracks().filter {
            $0.album?.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(title) == .orderedSame
                && (artist.isEmpty || $0.artist.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(artist) == .orderedSame)
        }
    }
    func fetchTracks(matchingArtist name: String) async throws -> [LocalTrack] {
        try await loadTracks().filter { ArtistCreditCleaner.containsArtist(name, in: $0.artist) }
    }
    func fetchMaintenancePage(afterPath: String?, limit: Int) async throws -> LocalMaintenancePage {
        let page = try await Array(loadTracks()
            .filter { track in afterPath.map { track.fileURL.standardizedFileURL.path > $0 } ?? true }
            .sorted { $0.fileURL.standardizedFileURL.path < $1.fileURL.standardizedFileURL.path }
            .prefix(max(1, limit)))
        return LocalMaintenancePage(tracks: page, nextPath: page.last?.fileURL.standardizedFileURL.path)
    }
    func findUniqueTrack(title: String, artist: String?) async throws -> LocalTrack? {
        let matches = try await loadTracks().filter {
            $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
                && (artist == nil || $0.artist.localizedCaseInsensitiveCompare(artist!) == .orderedSame)
        }
        return matches.count == 1 ? matches[0] : nil
    }
    func searchTracks(_ query: String, limit: Int) async throws -> [LocalTrack] {
        try await Array(loadTracks().filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
        }.prefix(max(0, limit)))
    }
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
        try await importTracksDetailed(from: urls).tracks
    }
    func importTracksDetailed(from urls: [URL]) async throws -> LocalImportResult {
        var imported: [LocalTrack] = []
        var failures: [LocalImportFailure] = []
        for url in urls {
            do {
                if let track = try await importTrack(from: url) {
                    imported.append(track)
                } else {
                    failures.append(LocalImportFailure(fileURL: url, reason: "No track was imported"))
                }
            } catch {
                failures.append(LocalImportFailure(fileURL: url, reason: error.localizedDescription))
            }
        }
        return LocalImportResult(tracks: imported, failures: failures)
    }
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {}
    func readTrack(from url: URL) async throws -> LocalTrack {
        try await SQLiteLocalLibraryRepository.readTrack(from: url)
    }
}

typealias FileLocalLibraryRepository = SQLiteLocalLibraryRepository
