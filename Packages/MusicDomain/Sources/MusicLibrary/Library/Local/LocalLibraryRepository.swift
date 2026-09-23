import Foundation
import AVFoundation
import MusicDomain

/// Local media I/O boundary. UI state and selection remain in the store/scene.
public protocol LocalLibraryRepository: Sendable {
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

public nonisolated struct LocalImportFailure: Sendable {
    public let fileURL: URL
    public let reason: String

    public init(fileURL: URL, reason: String) {
        self.fileURL = fileURL
        self.reason = reason
    }
}

public nonisolated struct LocalImportResult: Sendable {
    public let tracks: [LocalTrack]
    public let failures: [LocalImportFailure]

    public init(tracks: [LocalTrack], failures: [LocalImportFailure]) {
        self.tracks = tracks
        self.failures = failures
    }
}

public nonisolated struct LocalTrackPageRequest: Sendable {
    public enum Sort: String, Sendable {
        case dateAdded, title, artist, album, duration
    }
    public let query: String
    public let sort: Sort
    public let ascending: Bool
    public let offset: Int
    public let limit: Int

    public init(query: String = "", sort: Sort = .title, ascending: Bool = true,
         offset: Int = 0, limit: Int = 128) {
        self.query = query
        self.sort = sort
        self.ascending = ascending
        self.offset = max(0, offset)
        self.limit = min(max(1, limit), 512)
    }
}

public nonisolated struct LocalTrackPage: Sendable {
    public let tracks: [LocalTrack]
    public let totalCount: Int
    public let offset: Int
    public var hasMore: Bool { offset + tracks.count < totalCount }

    public init(
        tracks: [LocalTrack],
        totalCount: Int,
        offset: Int
    ) {
        self.tracks = tracks
        self.totalCount = totalCount
        self.offset = offset
    }
}

public nonisolated struct LocalMaintenancePage: Sendable {
    public let tracks: [LocalTrack]
    public let nextPath: String?

    public init(tracks: [LocalTrack], nextPath: String?) {
        self.tracks = tracks
        self.nextPath = nextPath
    }
}

extension LocalLibraryRepository {
    public func fetchTracks(withIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter {
            ids.contains($0.id) || ids.contains($0.fileURL.path)
                || ids.contains($0.fileURL.standardizedFileURL.path)
        }
    }
    public func fetchTracks(forReleaseIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter { track in
            guard let album = track.album else { return false }
            return ids.contains(DeterministicID.release(artist: track.artist, title: album).rawValue)
        }
    }
    public func fetchTracks(forArtistIDs ids: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter {
            ids.contains(DeterministicID.artist(name: $0.artist).rawValue)
        }
    }
    public func fetchTracks(inFolder folder: URL) async throws -> [LocalTrack] {
        let prefix = folder.standardizedFileURL.path
        return try await loadTracks().filter {
            let path = $0.fileURL.standardizedFileURL.path
            return path == prefix || path.hasPrefix(prefix + "/")
        }
    }
    public func fetchTracks(withFilenames names: Set<String>) async throws -> [LocalTrack] {
        try await loadTracks().filter { names.contains($0.fileURL.lastPathComponent) }
    }
    public func fetchTracks(matchingAlbum title: String, artist: String) async throws -> [LocalTrack] {
        try await loadTracks().filter {
            $0.album?.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(title) == .orderedSame
                && (artist.isEmpty || $0.artist.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(artist) == .orderedSame)
        }
    }
    public func fetchTracks(matchingArtist name: String) async throws -> [LocalTrack] {
        try await loadTracks().filter { ArtistCreditCleaner.containsArtist(name, in: $0.artist) }
    }
    public func fetchMaintenancePage(afterPath: String?, limit: Int) async throws -> LocalMaintenancePage {
        let page = try await Array(loadTracks()
            .filter { track in afterPath.map { track.fileURL.standardizedFileURL.path > $0 } ?? true }
            .sorted { $0.fileURL.standardizedFileURL.path < $1.fileURL.standardizedFileURL.path }
            .prefix(max(1, limit)))
        return LocalMaintenancePage(tracks: page, nextPath: page.last?.fileURL.standardizedFileURL.path)
    }
    public func findUniqueTrack(title: String, artist: String?) async throws -> LocalTrack? {
        let matches = try await loadTracks().filter {
            $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
                && (artist == nil || $0.artist.localizedCaseInsensitiveCompare(artist!) == .orderedSame)
        }
        return matches.count == 1 ? matches[0] : nil
    }
    public func searchTracks(_ query: String, limit: Int) async throws -> [LocalTrack] {
        try await Array(loadTracks().filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
        }.prefix(max(0, limit)))
    }
    public func fetchPage(_ request: LocalTrackPageRequest) async throws -> LocalTrackPage {
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
    public func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }
    public func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {}
    public func batchUpsertTracks(_ tracks: [LocalTrack]) async throws {
        try await saveTracksInPlace(tracks)
    }
    public func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        try await importTracksDetailed(from: urls).tracks
    }
    public func importTracksDetailed(from urls: [URL]) async throws -> LocalImportResult {
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
    public func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {}
    public func readTrack(from url: URL) async throws -> LocalTrack {
        try await SQLiteLocalLibraryRepository.readTrack(from: url)
    }
}

public typealias FileLocalLibraryRepository = SQLiteLocalLibraryRepository
