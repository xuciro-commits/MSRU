//
//  AlbumCluster.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation
import AppFoundation

/// An individual track entry participating in album-level clustering.
nonisolated public struct AlbumTrackItem: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let fileURL: URL
    public let title: String
    public let artist: String?
    public let album: String?
    public let trackNumber: Int?
    public let duration: TimeInterval
    public let acoustID: String?

    public init(
        id: String,
        fileURL: URL,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        trackNumber: Int? = nil,
        duration: TimeInterval = 0.0,
        acoustID: String? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.duration = duration
        self.acoustID = acoustID
    }
}

/// A coherent cluster of tracks believed to belong to the same album release.
///
/// Implements MusicBrainz Picard cluster methodology:
/// Groups files by folder structure, embedded album tags, track sequences, and duration totals
/// before executing authoritative catalog lookups.
nonisolated public struct AlbumCluster: Identifiable, Sendable, Equatable, Codable {

    /// Unique cluster identifier.
    public let id: String

    /// Common directory holding these tracks.
    public let folderURL: URL?

    /// Most frequent or consensus album title within the cluster.
    public let candidateAlbumTitle: String?

    /// Most frequent or consensus artist within the cluster.
    public let candidateArtist: String?

    /// Tracks belonging to this album cluster, sorted by track number or filename.
    public var tracks: [AlbumTrackItem]

    /// Combined total playback duration of all tracks.
    public var totalDuration: TimeInterval {
        tracks.reduce(0.0) { $0 + $1.duration }
    }

    /// Total track count in this cluster.
    public var trackCount: Int {
        tracks.count
    }

    /// Whether tracks exhibit an unbroken or recognizable sequential sequence (e.g. 1, 2, 3...).
    public var hasSequentialTrackNumbers: Bool {
        let numbers = tracks.compactMap(\.trackNumber)
        guard numbers.count == tracks.count, numbers.count > 1 else { return false }
        let sorted = numbers.sorted()
        return sorted == Array(1...numbers.count)
    }

    public init(
        id: String = UUID().uuidString,
        folderURL: URL? = nil,
        candidateAlbumTitle: String? = nil,
        candidateArtist: String? = nil,
        tracks: [AlbumTrackItem] = []
    ) {
        self.id = id
        self.folderURL = folderURL
        self.candidateAlbumTitle = candidateAlbumTitle
        self.candidateArtist = candidateArtist
        self.tracks = tracks
    }
}

/// Picard-style clustering engine.
nonisolated public enum AlbumClusterer {

    /// Groups an arbitrary set of track items into album clusters.
    public static func cluster(tracks: [AlbumTrackItem]) -> [AlbumCluster] {
        guard !tracks.isEmpty else { return [] }

        // Step 1: Primary grouping by parent folder URL
        var folderGroups: [URL: [AlbumTrackItem]] = [:]
        var unrooted: [AlbumTrackItem] = []

        for track in tracks {
            let parent = track.fileURL.deletingLastPathComponent()
            if parent.path.isEmpty || parent.path == "/" {
                unrooted.append(track)
            } else {
                folderGroups[parent, default: []].append(track)
            }
        }

        var clusters: [AlbumCluster] = []

        // Step 2: Sub-group each folder by album tag if multiple albums coexist in one directory
        for (folder, folderTracks) in folderGroups {
            let albumSubgroups = Dictionary(grouping: folderTracks) { track in
                StringDistance.normalize(track.album ?? "unknown_album")
            }

            for (_, albumTracks) in albumSubgroups {
                let sorted = sortTracks(albumTracks)
                let consensusAlbum = consensusValue(from: sorted.compactMap(\.album))
                let consensusArtist = consensusValue(from: sorted.compactMap(\.artist))

                clusters.append(AlbumCluster(
                    id: "\(folder.lastPathComponent):\(consensusAlbum ?? "album")",
                    folderURL: folder,
                    candidateAlbumTitle: consensusAlbum,
                    candidateArtist: consensusArtist,
                    tracks: sorted
                ))
            }
        }

        // Process unrooted
        if !unrooted.isEmpty {
            let sorted = sortTracks(unrooted)
            clusters.append(AlbumCluster(
                id: "unrooted_cluster",
                folderURL: nil,
                candidateAlbumTitle: consensusValue(from: sorted.compactMap(\.album)),
                candidateArtist: consensusValue(from: sorted.compactMap(\.artist)),
                tracks: sorted
            ))
        }

        return clusters
    }

    /// Sorts tracks by position/trackNumber if present, falling back to file name.
    private static func sortTracks(_ tracks: [AlbumTrackItem]) -> [AlbumTrackItem] {
        tracks.sorted { a, b in
            if let numA = a.trackNumber, let numB = b.trackNumber, numA != numB {
                return numA < numB
            }
            return a.fileURL.lastPathComponent.localizedStandardCompare(b.fileURL.lastPathComponent) == .orderedAscending
        }
    }

    /// Finds the most frequent non-empty string in a collection.
    private static func consensusValue(from values: [String]) -> String? {
        let nonEmpty = values.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for val in nonEmpty {
            counts[val, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
