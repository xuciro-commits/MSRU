//
//  Work.swift
//  MSRU
//

import Foundation

/// The genre/structure category of a musical work.
nonisolated public enum WorkType: String, Hashable, Codable, Sendable {
    case song
    case symphony
    case concerto
    case sonata
    case soundtrack
    case aria
    case suite
    case instrumental
    case poem
    case other
}

/// An abstract distinct musical composition or intellectual creation.
///
/// Distinct from any particular audio performance or release.
/// For example, "晴天" (composed & written by Jay Chou) or "Symphony No. 9 in D minor, Op. 125" (Beethoven).
nonisolated public struct Work: Identifiable, Hashable, Codable, Sendable {

    /// Stable Work identifier (e.g. MusicBrainz Work MBID).
    public let id: String

    /// The title of the work.
    public var title: String

    /// The structural work type.
    public var workType: WorkType

    /// Composers credited for the composition.
    public var composers: [ArtistEntity]

    /// Lyricists credited for words/lyrics.
    public var lyricists: [ArtistEntity]

    /// International Standard Musical Work Code (ISWC), if known.
    public var iswc: String?

    public init(
        id: String,
        title: String,
        workType: WorkType = .song,
        composers: [ArtistEntity] = [],
        lyricists: [ArtistEntity] = [],
        iswc: String? = nil
    ) {
        self.id = id
        self.title = title
        self.workType = workType
        self.composers = composers
        self.lyricists = lyricists
        self.iswc = iswc
    }
}
