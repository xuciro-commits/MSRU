import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import AppFoundation
import MusicDomain

/// Stable IDs are shared by the index writer and the system-result router.
public nonisolated enum SpotlightMusicID: Hashable, Sendable {
    case track(String)
    case album(String)
    case artist(String)

    public var rawValue: String {
        switch self {
        case .track(let id): "track:\(id)"
        case .album(let id): "album:\(id)"
        case .artist(let id): "artist:\(id)"
        }
    }

    public init?(rawValue: String) {
        guard let separator = rawValue.firstIndex(of: ":") else { return nil }
        let kind = rawValue[..<separator]
        let value = String(rawValue[rawValue.index(after: separator)...])
        guard !value.isEmpty else { return nil }
        switch kind {
        case "track": self = .track(value)
        case "album": self = .album(value)
        case "artist": self = .artist(value)
        default: return nil
        }
    }
}

public nonisolated struct SpotlightMusicRecord: Sendable, Hashable {
    public let id: SpotlightMusicID
    public let title: String
    public let artist: String?
    public let album: String?

    public init(track: LocalTrack) {
        id = .track(track.id)
        title = track.title
        artist = track.artist
        album = track.album
    }

    public init(album: AlbumPresentationModel) {
        id = .album(album.id)
        title = album.title
        artist = album.artist
        self.album = nil
    }

    public init(artist: ArtistPresentationModel) {
        id = .artist(artist.id)
        title = artist.name
        self.artist = nil
        album = nil
    }
}

public nonisolated struct SpotlightMusicSnapshot: Sendable {
    public let tracks: [LocalTrack]
    public let albums: [AlbumPresentationModel]
    public let artists: [ArtistPresentationModel]

    public init(
        tracks: [LocalTrack],
        albums: [AlbumPresentationModel],
        artists: [ArtistPresentationModel]
    ) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
    }
}

public nonisolated protocol SpotlightIndexWriting: Sendable {
    func removeLocalMusic() async throws
    func remove(ids: [String]) async throws
    func index(_ records: [SpotlightMusicRecord]) async throws
}

public nonisolated struct CoreSpotlightIndexWriter: SpotlightIndexWriting {
    private let domain = "com.msru.cn.MSRU.localMusic.v1"

    public func removeLocalMusic() async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain])
    }

    public func remove(ids: [String]) async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
    }

    public func index(_ records: [SpotlightMusicRecord]) async throws {
        let items = records.map { record in
            let type: UTType = {
                if case .track = record.id { return .audio }
                return .content
            }()
            let attributes = CSSearchableItemAttributeSet(contentType: type)
            attributes.title = record.title
            attributes.displayName = record.title
            attributes.artist = record.artist
            attributes.album = record.album
            let item = CSSearchableItem(
                uniqueIdentifier: record.id.rawValue,
                domainIdentifier: domain,
                attributeSet: attributes
            )
            return item
        }
        try await CSSearchableIndex.default().indexSearchableItems(items)
    }

    nonisolated public init() {}
}

public actor SpotlightIndexWorker {
    private let writer: any SpotlightIndexWriting
    private let batchSize: Int
    private var hasIndexed = false
    private var signatures: [String: Int] = [:]

    public init(writer: any SpotlightIndexWriting = CoreSpotlightIndexWriter(), batchSize: Int = 500) {
        self.writer = writer
        self.batchSize = max(1, batchSize)
    }

    public func rebuild(_ snapshot: SpotlightMusicSnapshot) async throws {
        try Task.checkCancellation()
        if !hasIndexed { try await writer.removeLocalMusic() }
        var nextSignatures: [String: Int] = [:]
        nextSignatures.reserveCapacity(snapshot.tracks.count + snapshot.albums.count + snapshot.artists.count)
        var batch: [SpotlightMusicRecord] = []
        batch.reserveCapacity(batchSize)

        for track in snapshot.tracks {
            try Task.checkCancellation()
            let record = SpotlightMusicRecord(track: track)
            let key = record.id.rawValue
            let signature = record.hashValue
            nextSignatures[key] = signature
            if signatures[key] != signature { batch.append(record) }
            if batch.count == batchSize {
                let ready = batch
                batch.removeAll(keepingCapacity: true)
                try await writer.index(ready)
            }
        }
        for album in snapshot.albums {
            try Task.checkCancellation()
            let record = SpotlightMusicRecord(album: album)
            let key = record.id.rawValue
            let signature = record.hashValue
            nextSignatures[key] = signature
            if signatures[key] != signature { batch.append(record) }
            if batch.count == batchSize {
                let ready = batch
                batch.removeAll(keepingCapacity: true)
                try await writer.index(ready)
            }
        }
        for artist in snapshot.artists {
            try Task.checkCancellation()
            let record = SpotlightMusicRecord(artist: artist)
            let key = record.id.rawValue
            let signature = record.hashValue
            nextSignatures[key] = signature
            if signatures[key] != signature { batch.append(record) }
            if batch.count == batchSize {
                let ready = batch
                batch.removeAll(keepingCapacity: true)
                try await writer.index(ready)
            }
        }
        if !batch.isEmpty {
            try Task.checkCancellation()
            try await writer.index(batch)
        }
        let removed = signatures.keys.filter { nextSignatures[$0] == nil }
        for start in stride(from: 0, to: removed.count, by: batchSize) {
            try Task.checkCancellation()
            try await writer.remove(ids: Array(removed[start..<min(start + batchSize, removed.count)]))
        }
        signatures = nextSignatures
        hasIndexed = true
    }

    /// Indexes local tracks page by page so startup never needs a resident full track array.
    public func rebuild(repository: any LocalLibraryRepository,
                 albums: [AlbumPresentationModel],
                 artists: [ArtistPresentationModel],
                 summaries: LocalSummaryRepository? = nil) async throws {
        try Task.checkCancellation()
        if !hasIndexed { try await writer.removeLocalMusic() }
        var nextSignatures: [String: Int] = [:]
        var batch: [SpotlightMusicRecord] = []
        batch.reserveCapacity(batchSize)

        func accept(_ record: SpotlightMusicRecord) -> [SpotlightMusicRecord]? {
            let key = record.id.rawValue
            let signature = record.hashValue
            nextSignatures[key] = signature
            if signatures[key] != signature { batch.append(record) }
            if batch.count >= batchSize {
                let ready = batch
                batch.removeAll(keepingCapacity: true)
                return ready
            }
            return nil
        }

        var offset = 0
        while true {
            try Task.checkCancellation()
            let page = try await repository.fetchPage(
                LocalTrackPageRequest(sort: .title, offset: offset, limit: min(batchSize, 512))
            )
            for track in page.tracks {
                try Task.checkCancellation()
                if let ready = accept(SpotlightMusicRecord(track: track)) {
                    try await writer.index(ready)
                }
            }
            offset += page.tracks.count
            if !page.hasMore { break }
            guard !page.tracks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        }
        if let summaries {
            var albumOffset = 0
            while true {
                try Task.checkCancellation()
                let page = try await summaries.albumPage(offset: albumOffset, limit: min(batchSize, 256))
                for album in page.items {
                    if let ready = accept(SpotlightMusicRecord(album: album)) {
                        try await writer.index(ready)
                    }
                }
                albumOffset += page.items.count
                if !page.hasMore { break }
                guard !page.items.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            }
            var artistOffset = 0
            while true {
                try Task.checkCancellation()
                let page = try await summaries.artistPage(offset: artistOffset, limit: min(batchSize, 256))
                for artist in page.items {
                    if let ready = accept(SpotlightMusicRecord(artist: artist)) {
                        try await writer.index(ready)
                    }
                }
                artistOffset += page.items.count
                if !page.hasMore { break }
                guard !page.items.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            }
        } else {
            for album in albums {
                try Task.checkCancellation()
                if let ready = accept(SpotlightMusicRecord(album: album)) {
                    try await writer.index(ready)
                }
            }
            for artist in artists {
                try Task.checkCancellation()
                if let ready = accept(SpotlightMusicRecord(artist: artist)) {
                    try await writer.index(ready)
                }
            }
        }
        if !batch.isEmpty { try await writer.index(batch) }

        let removed = signatures.keys.filter { nextSignatures[$0] == nil }
        for start in stride(from: 0, to: removed.count, by: batchSize) {
            try Task.checkCancellation()
            try await writer.remove(ids: Array(removed[start..<min(start + batchSize, removed.count)]))
        }
        signatures = nextSignatures
        hasIndexed = true
    }
}

/// Coalesces library mutations; the expensive indexing work stays off MainActor.
@MainActor
public final class SpotlightIndexingService {
    private let worker: SpotlightIndexWorker
    private var pending: Task<Void, Never>?

    public init(worker: SpotlightIndexWorker = SpotlightIndexWorker()) {
        self.worker = worker
    }

    public func schedule(_ snapshot: SpotlightMusicSnapshot) {
        pending?.cancel()
        let previous = pending
        pending = Task { [worker] in
            _ = await previous?.value
            do {
                try await Task.sleep(for: .milliseconds(700))
                try await worker.rebuild(snapshot)
            } catch is CancellationError {
                // Superseded by a newer library revision.
            } catch {
                print("[SpotlightIndex] Index update failed: \(error)")
            }
        }
    }

    public func schedule(repository: any LocalLibraryRepository,
                  albums: [AlbumPresentationModel],
                  artists: [ArtistPresentationModel],
                  summaries: LocalSummaryRepository? = nil) {
        pending?.cancel()
        let previous = pending
        pending = Task { [worker] in
            _ = await previous?.value
            do {
                try await Task.sleep(for: .milliseconds(700))
                try await worker.rebuild(repository: repository, albums: albums,
                                         artists: artists, summaries: summaries)
            } catch is CancellationError {
                // Superseded by a newer library revision.
            } catch {
                print("[SpotlightIndex] Paged index update failed: \(error)")
            }
        }
    }

    public func schedule(repository: any LocalLibraryRepository, summaries: LocalSummaryRepository) {
        schedule(repository: repository, albums: [], artists: [], summaries: summaries)
    }

    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}
