import Foundation
import Observation

/// Application-owned saved library. Writes are serialized and become visible only
/// after persistence succeeds; a failed load must never be overwritten by an add.
@MainActor
@Observable
final class LibraryStore {
    private(set) var tracks: [LibraryTrack] = []
    private(set) var savedLocalURLs: Set<URL> = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private let repository: any LibraryRepository
    private var pendingOperation: Task<Bool, Never>?
    private var operationID: UUID?

    convenience init() { self.init(repository: SQLiteLibraryRepository()) }
    init(repository: any LibraryRepository) {
        self.repository = repository
        rebuildIndex()
    }

    func load() async {
        _ = await serialized { await self.loadNow() }
    }

    private func loadNow() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tracks = try await repository.loadTracks().sorted { $0.dateAdded > $1.dateAdded }
            rebuildIndex()
            hasLoaded = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func contains(id: UUID) -> Bool { track(id: id) != nil }
    func track(id: UUID) -> LibraryTrack? { tracks.first { $0.id == id } }
    func contains(source: LibraryPlaybackSource) -> Bool { track(containing: source) != nil }
    func track(containing source: LibraryPlaybackSource) -> LibraryTrack? {
        tracks.first { track in track.sources.contains { isSameSource($0, source) } }
    }
    func contains(local track: LocalTrack) -> Bool {
        savedLocalURLs.contains(track.fileURL)
            || savedLocalURLs.contains(track.fileURL.standardizedFileURL)
            || savedLocalURLs.contains(track.fileURL.resolvingSymlinksInPath().standardizedFileURL)
    }
    func libraryTrack(for localTrack: LocalTrack) -> LibraryTrack? {
        track(containing: LibraryPlaybackSource(local: localTrack))
    }
    func contains(openverse track: OpenverseAudio) -> Bool { contains(source: LibraryPlaybackSource(openverse: track)) }
    func libraryTrack(for openverseTrack: OpenverseAudio) -> LibraryTrack? {
        track(containing: LibraryPlaybackSource(openverse: openverseTrack))
    }

    @discardableResult
    func add(_ track: LibraryTrack) async -> Bool {
        await mutate { current in
            guard !current.contains(where: { $0.id == track.id }),
                  !track.sources.contains(where: { source in
                      current.contains { $0.sources.contains { self.isSameSource($0, source) } }
                  }) else { return nil }
            return [track] + current
        }
    }
    @discardableResult
    func add(local track: LocalTrack) async -> Bool { await add(LibraryTrack(local: track)) }
    @discardableResult
    func add(openverse track: OpenverseAudio) async -> Bool { await add(LibraryTrack(openverse: track)) }

    @discardableResult
    func remove(id: UUID) async -> Bool {
        await mutate { current in
            guard current.contains(where: { $0.id == id }) else { return nil }
            return current.filter { $0.id != id }
        }
    }
    func remove(local track: LocalTrack) async { await removeTrack(containing: LibraryPlaybackSource(local: track)) }
    func remove(openverse track: OpenverseAudio) async { await removeTrack(containing: LibraryPlaybackSource(openverse: track)) }

    /// Purges tracks matching specified IDs or file URLs from the saved library in a single atomic save.
    func purgeTracks(matchingIDs ids: Set<String>, localURLs: Set<URL>) async {
        guard !ids.isEmpty || !localURLs.isEmpty else { return }
        _ = await mutate { current in
            let filtered = current.filter { track in
                if ids.contains(track.id.uuidString) { return false }
                for source in track.sources {
                    if let url = source.localFileURL {
                        if localURLs.contains(url) || ids.contains(url.path) || ids.contains(url.standardizedFileURL.path) {
                            return false
                        }
                    }
                    if let extID = source.externalID, ids.contains(extID) {
                        return false
                    }
                }
                return true
            }
            return filtered.count != current.count ? filtered : nil
        }
    }

    private func removeTrack(containing source: LibraryPlaybackSource) async {
        _ = await mutate { current in
            guard let track = current.first(where: { $0.sources.contains { self.isSameSource($0, source) } }) else { return nil }
            return current.filter { $0.id != track.id }
        }
    }

    func update(_ track: LibraryTrack) async {
        _ = await mutate { current in
            guard let index = current.firstIndex(where: { $0.id == track.id }) else { return nil }
            var updated = current
            updated[index] = track
            return updated
        }
    }

    @discardableResult
    func addSource(_ source: LibraryPlaybackSource, toTrackID trackID: UUID) async -> Bool {
        await mutate { current in
            guard let index = current.firstIndex(where: { $0.id == trackID }),
                  !current.contains(where: { $0.sources.contains { self.isSameSource($0, source) } }) else { return nil }
            var updated = current
            updated[index].sources.append(source)
            return updated
        }
    }

    func markPlayed(id: UUID) async {
        _ = await mutate { current in
            guard let index = current.firstIndex(where: { $0.id == id }) else { return nil }
            var updated = current
            updated[index].lastPlayedAt = Date()
            return updated
        }
    }

    private func isSameSource(_ lhs: LibraryPlaybackSource, _ rhs: LibraryPlaybackSource) -> Bool {
        guard lhs.kind == rhs.kind else { return false }
        if lhs.kind == .local, let left = lhs.localFileURL, let right = rhs.localFileURL {
            return left.resolvingSymlinksInPath().standardizedFileURL
                == right.resolvingSymlinksInPath().standardizedFileURL
        }
        if let left = lhs.externalID, let right = rhs.externalID { return left == right }
        if let left = lhs.localFileURL, let right = rhs.localFileURL {
            return left.standardizedFileURL == right.standardizedFileURL
        }
        if let left = lhs.remoteURL, let right = rhs.remoteURL { return left == right }
        return false
    }

    private func mutate(_ change: @escaping @MainActor ([LibraryTrack]) -> [LibraryTrack]?) async -> Bool {
        await serialized {
            if !self.hasLoaded, !(await self.loadNow()) { return false }
            guard let updated = change(self.tracks) else { return false }
            self.isSaving = true
            self.errorMessage = nil
            defer { self.isSaving = false }
            do {
                let oldByID = Dictionary(uniqueKeysWithValues: self.tracks.map { ($0.id, $0) })
                let newIDs = Set(updated.map(\.id))
                let upserts = updated.filter { oldByID[$0.id] != $0 }
                let deletes = Set(oldByID.keys).subtracting(newIDs)
                try await self.repository.applyChanges(upserting: upserts, deleting: deletes)
                self.tracks = updated
                self.rebuildIndex()
                return true
            } catch {
                self.errorMessage = error.localizedDescription
                return false
            }
        }
    }

    private func rebuildIndex() {
        var urls = Set<URL>()
        for track in tracks {
            for source in track.sources {
                if let url = source.localFileURL {
                    urls.insert(url.resolvingSymlinksInPath().standardizedFileURL)
                    urls.insert(url.standardizedFileURL)
                    urls.insert(url)
                }
            }
        }
        self.savedLocalURLs = urls
    }

    private func serialized(_ operation: @escaping @MainActor () async -> Bool) async -> Bool {
        let previous = pendingOperation
        let id = UUID()
        let task = Task { @MainActor in
            _ = await previous?.value
            return await operation()
        }
        pendingOperation = task
        operationID = id
        let result = await task.value
        if operationID == id {
            pendingOperation = nil
            operationID = nil
        }
        return result
    }
}
