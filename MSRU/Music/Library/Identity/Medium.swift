//
//  Medium.swift
//  MSRU
//

import Foundation

/// A physical or logical disc, vinyl side, or tape cassette comprising a Release.
nonisolated public struct Medium: Identifiable, Hashable, Codable, Sendable {

    /// Unique medium identifier.
    public let id: String

    /// 1-based disc number (e.g. 1 for Disc 1, 2 for Disc 2).
    public let position: Int

    /// Format of the medium (e.g. "CD", "12\" Vinyl", "Digital Media", "Cassette").
    public var format: String?

    /// Optional disc subtitle (e.g. "Bonus Disc", "The Remixes").
    public var title: String?

    /// Ordered tracks sequenced on this medium.
    public var tracks: [MusicTrack]

    public init(
        id: String = UUID().uuidString,
        position: Int,
        format: String? = "Digital Media",
        title: String? = nil,
        tracks: [MusicTrack] = []
    ) {
        self.id = id
        self.position = position
        self.format = format
        self.title = title
        self.tracks = tracks
    }

    /// Total track count on this medium.
    public var trackCount: Int {
        tracks.count
    }
}
