import Foundation
import Observation

@MainActor @Observable
final class LocalTrackPager {
    private let repository: any LocalLibraryRepository
    private let pageSize = 128
    private var generation = 0
    private var query = ""
    private var sort: LocalTrackPageRequest.Sort = .title
    private var ascending = true

    private(set) var tracks: [LocalTrack] = []
    private(set) var totalCount = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(repository: any LocalLibraryRepository) {
        self.repository = repository
    }

    var hasMore: Bool { tracks.count < totalCount }

    func reset(query: String, sort: LocalTrackPageRequest.Sort, ascending: Bool) async {
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

    func loadMore() async {
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
}
