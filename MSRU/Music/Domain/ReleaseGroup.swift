//
//  ReleaseGroup.swift
//  MSRU
//

import Foundation

/// Primary classification of an album-level release group.
nonisolated public enum ReleaseGroupType: String, Hashable, Codable, Sendable {
    case album
    case single
    case ep
    case broadcast
    case other
    case compilation
    case soundtrack
    case live
    case remix
}

/// An abstract album concept grouping various physical and digital releases together.
///
/// Example: "叶惠美" is the ReleaseGroup.
/// Its constituent releases include the 2003 Taiwan CD, 2003 Hong Kong Edition, 2020 Remastered Vinyl.
nonisolated public struct ReleaseGroup: Identifiable, Hashable, Codable, Sendable {

    /// Stable ReleaseGroup MBID.
    public let id: String

    /// The definitive title of the album concept.
    public var title: String

    /// The credited primary artist for the entire release group (e.g. "Jay Chou" or "Various Artists").
    public var artistCredit: ArtistCredit

    /// The primary album type.
    public var primaryType: ReleaseGroupType

    /// Secondary tags (e.g. soundtrack, compilation).
    public var secondaryTypes: [ReleaseGroupType]

    /// Earliest known release date (e.g. "2003-07-31").
    public var firstReleaseDate: String?

    public init(
        id: String,
        title: String,
        artistCredit: ArtistCredit,
        primaryType: ReleaseGroupType = .album,
        secondaryTypes: [ReleaseGroupType] = [],
        firstReleaseDate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistCredit = artistCredit
        self.primaryType = primaryType
        self.secondaryTypes = secondaryTypes
        self.firstReleaseDate = firstReleaseDate
    }
}
