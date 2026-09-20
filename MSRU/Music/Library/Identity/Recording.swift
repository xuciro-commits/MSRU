//
//  Recording.swift
//  MSRU
//

import Foundation

/// A unique audio performance capture of a musical work.
///
/// Anchored by an acoustic identity (e.g. AcoustID) and MBID.
/// Studio version vs Live 1994 are separate Recordings of the same Work.
nonisolated public struct Recording: Identifiable, Hashable, Codable, Sendable {

    /// Stable Recording MBID (e.g. "a225bb13-5b8f-4da0-9908-410a563f8582").
    public let id: String

    /// The title of this recording.
    public var title: String

    /// Credited artists performing on this recording.
    public var artistCredit: ArtistCredit

    /// Reference to the underlying abstract musical work, if identified.
    public var workID: String?

    /// Expected reference duration of this recording in seconds.
    public var duration: TimeInterval?

    /// International Standard Recording Code (ISRC), if known.
    public var isrc: String?

    /// Whether this recording is a live performance capture.
    public var isLive: Bool

    /// Acoustic fingerprint reference (AcoustID).
    public var acoustID: String?

    public init(
        id: String,
        title: String,
        artistCredit: ArtistCredit,
        workID: String? = nil,
        duration: TimeInterval? = nil,
        isrc: String? = nil,
        isLive: Bool = false,
        acoustID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistCredit = artistCredit
        self.workID = workID
        self.duration = duration
        self.isrc = isrc
        self.isLive = isLive
        self.acoustID = acoustID
    }
}
