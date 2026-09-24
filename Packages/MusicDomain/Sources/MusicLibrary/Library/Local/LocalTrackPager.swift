import Foundation
import Observation
import MusicDomain

@MainActor @Observable
public final class LocalTrackPager {
    private let repository: any LocalLibraryRepository
    private let pageSize = 128
    private var generation = 0
    private var query = ""
    private var sort: LocalTrackPageRequest.Sort = .title
    private var ascending = true

    public private(set) var tracks: [LocalTrack] = []
    public private(set) var totalCount = 0
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public init(repository: any LocalLibraryRepository) {
        self.repository = repository
    }

    public var hasMore: Bool { tracks.count < totalCount }

    public func makePlaybackPageSource() -> LocalPlaybackPageSource? {
        guard hasMore else { return nil }
        return LocalPlaybackPageSource(
            repository: repository, query: query, sort: sort, ascending: ascending,
            offset: tracks.count, totalCount: totalCount
        )
    }

    public func reset(query: String, sort: LocalTrackPageRequest.Sort, ascending: Bool) async {
        generation &+= 1
        self.query = query
        self.sort = sort
        self.ascending = ascending
        tracks = []
        totalCount = 0
        errorMessage = nil
        isLoading = false
        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, tracks.isEmpty || hasMore else { return }
        isLoading = true
        let currentGeneration = generation
        let request = LocalTrackPageRequest(query: query, sort: sort, ascending: ascending,
                                            offset: tracks.count, limit: pageSize)
        do {
            let page = try await repository.fetchPage(request)
            guard currentGeneration == generation else { return }
            tracks.append(contentsOf: page.tracks)
            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        if currentGeneration == generation { isLoading = false }
    }

    /// Updates specific tracks in-place without altering the loaded count or scroll offset.
    public func updateTracksInPlace(_ updatedTracks: [LocalTrack]) {
        guard !updatedTracks.isEmpty else { return }
        let map = Dictionary(uniqueKeysWithValues: updatedTracks.map { ($0.id, $0) })
        for i in tracks.indices {
            if let fresh = map[tracks[i].id] {
                tracks[i] = fresh
            }
        }
    }

    /// Reloads currently loaded tracks preserving the loaded range count so the table doesn't collapse to page 1 or jump to the top.
    public func reload(preserveCount: Bool = true) async {
        guard !isLoading else { return }
        let currentCount = preserveCount ? max(tracks.count, pageSize) : pageSize
        let currentGeneration = generation
        isLoading = true
        let request = LocalTrackPageRequest(
            query: query,
            sort: sort,
            ascending: ascending,
            offset: 0,
            limit: currentCount
        )
        do {
            let page = try await repository.fetchPage(request)
            guard currentGeneration == generation else { return }
            tracks = page.tracks
            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        if currentGeneration == generation { isLoading = false }
    }
}

@MainActor
public final class LocalPlaybackPageSource {
    private let repository: any LocalLibraryRepository
    private let query: String
    private let sort: LocalTrackPageRequest.Sort
    private let ascending: Bool
    private var offset: Int
    private var totalCount: Int

    public init(repository: any LocalLibraryRepository, query: String,
         sort: LocalTrackPageRequest.Sort, ascending: Bool,
         offset: Int, totalCount: Int) {
        self.repository = repository
        self.query = query
        self.sort = sort
        self.ascending = ascending
        self.offset = offset
        self.totalCount = totalCount
    }

    public var hasMore: Bool { offset < totalCount }

    public func nextPage() async throws -> [LocalTrack] {
        guard hasMore else { return [] }
        let page = try await repository.fetchPage(LocalTrackPageRequest(
            query: query, sort: sort, ascending: ascending, offset: offset, limit: 128
        ))
        guard !page.tracks.isEmpty || !page.hasMore else { throw CocoaError(.fileReadCorruptFile) }
        offset += page.tracks.count
        totalCount = page.totalCount
        return page.tracks
    }
}
