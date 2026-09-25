import Foundation
import Observation
import AppFoundation
import MusicDomain

@MainActor @Observable
public final class LocalAlbumPager {
    private let repository: LocalSummaryRepository
    private var generation = 0
    private var query = ""
    private var sort: LocalSummaryRepository.AlbumSort = .title
    private var sourceFilter: String? = nil

    public private(set) var albums: [AlbumPresentationModel] = []
    public private(set) var totalCount = 0
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public init(repository: LocalSummaryRepository) { self.repository = repository }
    public var hasMore: Bool { albums.count < totalCount }

    public func reset(query: String, sort: LocalSummaryRepository.AlbumSort, sourceFilter: String? = nil) async {
        generation &+= 1
        self.query = query
        self.sort = sort
        self.sourceFilter = sourceFilter
        albums = []
        totalCount = 0
        errorMessage = nil
        isLoading = false
        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, errorMessage == nil, albums.isEmpty || hasMore else { return }
        isLoading = true
        let currentGeneration = generation
        do {
            let page = try await repository.albumPage(query: query, sort: sort, offset: albums.count, sourceFilter: sourceFilter)
            guard currentGeneration == generation else { return }
            albums.append(contentsOf: page.items)
            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        if currentGeneration == generation { isLoading = false }
    }

    public func retry() async {
        errorMessage = nil
        await loadMore()
    }

    /// Reloads currently loaded albums preserving the loaded count so views don't jump to the top.
    public func reload(preserveCount: Bool = true) async {
        guard !isLoading else { return }
        let currentCount = preserveCount ? max(albums.count, 64) : 64
        let currentGeneration = generation
        isLoading = true
        do {
            let page = try await repository.albumPage(query: query, sort: sort, offset: 0, limit: currentCount, sourceFilter: sourceFilter)
            guard currentGeneration == generation else { return }
            albums = page.items
            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        if currentGeneration == generation { isLoading = false }
    }
}

@MainActor @Observable
public final class LocalArtistPager {
    private let repository: LocalSummaryRepository
    private var generation = 0
    private var query = ""
    private var sourceFilter: String? = nil

    public private(set) var artists: [ArtistPresentationModel] = []
    public private(set) var totalCount = 0
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public init(repository: LocalSummaryRepository) { self.repository = repository }
    public var hasMore: Bool { artists.count < totalCount }

    public func reset(query: String, sourceFilter: String? = nil) async {
        generation &+= 1
        self.query = query
        self.sourceFilter = sourceFilter
        artists = []
        totalCount = 0
        errorMessage = nil
        isLoading = false
        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, errorMessage == nil, artists.isEmpty || hasMore else { return }
        isLoading = true
        let currentGeneration = generation
        do {
            let page = try await repository.artistPage(query: query, offset: artists.count, sourceFilter: sourceFilter)
            guard currentGeneration == generation else { return }
            artists.append(contentsOf: page.items)
            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        if currentGeneration == generation { isLoading = false }
    }

    public func retry() async {
        errorMessage = nil
        await loadMore()
    }

    /// Reloads currently loaded artists preserving the loaded count so views don't jump to the top.
    public func reload(preserveCount: Bool = true) async {
        guard !isLoading else { return }
        let currentCount = preserveCount ? max(artists.count, 64) : 64
        let currentGeneration = generation
        isLoading = true
        do {
            let page = try await repository.artistPage(query: query, offset: 0, limit: currentCount, sourceFilter: sourceFilter)
            guard currentGeneration == generation else { return }
            artists = page.items
            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        if currentGeneration == generation { isLoading = false }
    }
}
