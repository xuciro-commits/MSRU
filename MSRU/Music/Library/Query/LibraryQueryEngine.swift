//
//  LibraryQueryEngine.swift
//  MSRU
//
//  Dedicated actor for query index maintenance, filtered/sorted ID ordering,
//  ID-to-position mapping, group summaries, and revisioned snapshot publishing.
//

import Foundation
import AppFoundation

/// Lightweight queryable track descriptor for the Query Engine.
/// Keeps Query Engine decoupled from concrete repository or storage implementations.
nonisolated public struct QueryTrackItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval
    public let trackNumber: Int?
    public let year: Int?
    public let artworkReference: String?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        trackNumber: Int? = nil,
        year: Int? = nil,
        artworkReference: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.year = year
        self.artworkReference = artworkReference
    }

    public init(localTrack: LocalTrack) {
        self.init(
            id: localTrack.id,
            title: localTrack.title,
            artist: localTrack.artist,
            album: localTrack.album,
            duration: localTrack.duration,
            trackNumber: localTrack.trackNumber,
            year: localTrack.year,
            artworkReference: localTrack.artworkReference
        )
    }
}

/// Immutable, revisioned query projection snapshot.
nonisolated public struct LibraryQuerySnapshot: Sendable {
    public let revision: UInt64
    public let orderedIDs: [String]
    public let positionLookup: [String: Int] // trackID -> 1-based index
    public let albumSummaries: [AlbumPresentationModel]
    public let artistSummaries: [ArtistPresentationModel]

    public init(
        revision: UInt64 = 0,
        orderedIDs: [String] = [],
        positionLookup: [String: Int] = [:],
        albumSummaries: [AlbumPresentationModel] = [],
        artistSummaries: [ArtistPresentationModel] = []
    ) {
        self.revision = revision
        self.orderedIDs = orderedIDs
        self.positionLookup = positionLookup
        self.albumSummaries = albumSummaries
        self.artistSummaries = artistSummaries
    }

    public var isEmpty: Bool {
        orderedIDs.isEmpty
    }

    public var count: Int {
        orderedIDs.count
    }

    public func position(of id: String) -> Int? {
        positionLookup[id]
    }
}

/// Dedicated query engine actor with revision-tracked cancellation and coalescing.
public actor LibraryQueryEngine {

    public static let shared = LibraryQueryEngine()

    private var sourceItems: [QueryTrackItem] = []
    private var currentRevision: UInt64 = 0
    private var inFlightJob: Task<LibraryQuerySnapshot, Never>?

    public init() {}

    /// Ingests updated track items from the store, bumping revision and invalidating obsolete in-flight jobs.
    @discardableResult
    public func setSourceTracks(_ tracks: [QueryTrackItem]) -> UInt64 {
        sourceItems = tracks
        currentRevision &+= 1
        inFlightJob?.cancel()
        inFlightJob = nil
        return currentRevision
    }

    @discardableResult
    public func setSourceLocalTracks(_ tracks: [LocalTrack]) -> UInt64 {
        let items = tracks.map { QueryTrackItem(localTrack: $0) }
        return setSourceTracks(items)
    }

    /// Computes or returns an immutable query snapshot for the current revision.
    /// Superseded computations are cancelled and guaranteed never to publish.
    public func querySnapshot() async -> LibraryQuerySnapshot {
        let revision = currentRevision

        // If there's an active in-flight job for the same revision, await it
        if let inFlight = inFlightJob {
            let result = await inFlight.value
            if result.revision == revision {
                return result
            }
        }

        let items = sourceItems
        let task = Task<LibraryQuerySnapshot, Never> { () -> LibraryQuerySnapshot in
            guard !Task.isCancelled else {
                return LibraryQuerySnapshot(revision: revision)
            }

            // 1. Position and ID ordering
            var orderedIDs: [String] = []
            orderedIDs.reserveCapacity(items.count)
            var positionLookup: [String: Int] = [:]
            positionLookup.reserveCapacity(items.count)

            for (index, item) in items.enumerated() {
                orderedIDs.append(item.id)
                positionLookup[item.id] = index + 1
            }

            guard !Task.isCancelled else {
                return LibraryQuerySnapshot(revision: revision)
            }

            // 2. Group summaries (Albums and Artists)
            let albums = Self.buildAlbumSummaries(from: items)
            let artists = Self.buildArtistSummaries(from: items)

            guard !Task.isCancelled else {
                return LibraryQuerySnapshot(revision: revision)
            }

            return LibraryQuerySnapshot(
                revision: revision,
                orderedIDs: orderedIDs,
                positionLookup: positionLookup,
                albumSummaries: albums,
                artistSummaries: artists
            )
        }

        inFlightJob = task
        let snapshot = await task.value
        inFlightJob = nil

        // Stale result check: if revision changed while running, discard and re-query
        if snapshot.revision != currentRevision {
            return await querySnapshot()
        }

        return snapshot
    }

    /// Background grouping for Album Presentation Models
    private static func buildAlbumSummaries(from items: [QueryTrackItem]) -> [AlbumPresentationModel] {
        var albumGroups: [String: [QueryTrackItem]] = [:]

        for track in items {
            let key = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? "\(track.artist) — \(track.album!)"
                : "\(track.artist) — Unknown Album"
            albumGroups[key, default: []].append(track)
        }

        var models: [AlbumPresentationModel] = []

        for (key, tracks) in albumGroups {
            guard let first = tracks.first else { continue }
            let artist = first.artist
            let albumTitle = (first.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? first.album!
                : "Unknown Album"

            let totalDuration = tracks.reduce(0.0) { $0 + $1.duration }

            let presentationTracks = tracks.enumerated().map { index, track in
                let trackNum = track.trackNumber ?? (index + 1)
                return TrackPresentationModel(
                    id: track.id,
                    trackNumber: trackNum,
                    title: track.title,
                    artist: track.artist,
                    duration: track.duration,
                    formatBadge: (track.id as NSString).pathExtension.uppercased(),
                    versionCount: 1
                )
            }.sorted { $0.trackNumber < $1.trackNumber }

            let year = tracks.compactMap(\.year).first
            let disc = DiscTrackGroup(discNumber: 1, discTitle: nil, tracks: presentationTracks)
            let albumArtworkRef = tracks.compactMap(\.artworkReference).first

            let model = AlbumPresentationModel(
                id: key,
                title: albumTitle,
                artist: artist,
                year: year,
                artworkData: nil,
                artworkURL: nil,
                artworkReference: albumArtworkRef,
                trackCount: tracks.count,
                duration: totalDuration,
                audioQualityBadge: "Lossless",
                discs: [disc]
            )
            models.append(model)
        }

        return models.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Background grouping for Artist Presentation Models
    private static func buildArtistSummaries(from items: [QueryTrackItem]) -> [ArtistPresentationModel] {
        var artistGroups: [String: [QueryTrackItem]] = [:]

        for track in items {
            let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = artist.isEmpty ? "Unknown Artist" : artist
            artistGroups[key, default: []].append(track)
        }

        var models: [ArtistPresentationModel] = []

        for (artistName, tracks) in artistGroups {
            let albumsCount = Set(tracks.compactMap { $0.album }).count
            let artistArtworkRef = tracks.compactMap(\.artworkReference).first
            let model = ArtistPresentationModel(
                id: artistName,
                name: artistName,
                aliases: [],
                country: nil,
                albumCount: max(1, albumsCount),
                trackCount: tracks.count,
                artworkData: nil,
                artworkURL: nil,
                artworkReference: artistArtworkRef
            )
            models.append(model)
        }

        return models.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
