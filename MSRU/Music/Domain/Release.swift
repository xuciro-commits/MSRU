//
//  Release.swift
//  MSRU
//

import Foundation

/// A concrete physical or digital product issue of a ReleaseGroup.
///
/// Example: "叶惠美 2003 台湾首发版" (Alfa Music CD) or "叶惠美 2020 经典黑胶版".
/// Contains country, date, barcode, and medium discs.
nonisolated public struct Release: Identifiable, Hashable, Codable, Sendable {

    /// Stable Release MBID (e.g. "a1b2c3d4-0000-4000-8000-000000000001").
    public let id: String

    /// Identifier of the parent abstract album concept (`ReleaseGroup`).
    public let releaseGroupID: String

    /// Title as issued on this release.
    public var title: String

    /// Credited artist for this release issue.
    public var artistCredit: ArtistCredit

    /// Release date string (ISO format: "2003-07-31" or "2003").
    public var date: String?

    /// Two-letter country code (e.g. "TW", "US", "JP", "GB").
    public var country: String?

    /// Barcode / UPC / EAN.
    public var barcode: String?

    /// Record label / publishing imprint.
    public var label: String?

    /// Catalog number assigned by label.
    public var catalogueNumber: String?

    /// Physical packaging description.
    public var packaging: String?

    /// Constituent discs / mediums in this release.
    public var media: [Medium]

    public init(
        id: String,
        releaseGroupID: String,
        title: String,
        artistCredit: ArtistCredit,
        date: String? = nil,
        country: String? = nil,
        barcode: String? = nil,
        label: String? = nil,
        catalogueNumber: String? = nil,
        packaging: String? = nil,
        media: [Medium] = []
    ) {
        self.id = id
        self.releaseGroupID = releaseGroupID
        self.title = title
        self.artistCredit = artistCredit
        self.date = date
        self.country = country
        self.barcode = barcode
        self.label = label
        self.catalogueNumber = catalogueNumber
        self.packaging = packaging
        self.media = media
    }

    /// Flattens all tracks across all discs in sequential order.
    public var allTracks: [MusicTrack] {
        media.flatMap(\.tracks)
    }

    /// Total track count across all discs.
    public var totalTrackCount: Int {
        allTracks.count
    }
}
