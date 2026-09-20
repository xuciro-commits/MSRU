//
//  MusicTrack.swift
//  MSRU
//

import Foundation

/// A single track as sequenced on a specific Medium of a Release.
///
/// Distinct from `Recording`: a Recording represents the performance capture,
/// while `MusicTrack` represents its position and title on a CD/disc.
nonisolated public struct MusicTrack: Identifiable, Hashable, Codable, Sendable {

    /// Stable Track MBID or generated ID.
    public let id: String

    /// Identifier of the audio recording contained on this track.
    public let recordingID: String

    /// 1-based sequential position on this medium (e.g. 1, 2, 3...).
    public let position: Int

    /// Track number string as printed on sleeve/cue (e.g. "01", "A1", "B2").
    public let number: String

    /// Title of the track on this specific release.
    public let title: String

    /// Specific track artist credit if different from the album release artist.
    public let artistCredit: ArtistCredit?

    /// Duration of the track on this medium in seconds.
    public let duration: TimeInterval?

    public init(
        id: String,
        recordingID: String,
        position: Int,
        number: String? = nil,
        title: String,
        artistCredit: ArtistCredit? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.recordingID = recordingID
        self.position = position
        self.number = number ?? "\(position)"
        self.title = title
        self.artistCredit = artistCredit
        self.duration = duration
    }
}
