//
//  ArtistCredit.swift
//  MSRU
//

import Foundation
import AppFoundation

/// The functional role an artist played on a recording or release.
nonisolated public enum ArtistRole: String, Hashable, Codable, Sendable {
    case primary
    case featured
    case producer
    case remixer
    case composer
    case lyricist
    case arranger
    case conductor
    case performer
}

/// An individual artist's participation within an `ArtistCredit`.
nonisolated public struct ArtistParticipation: Identifiable, Hashable, Codable, Sendable {

    public var id: String {
        "\(artist.id):\(role.rawValue)"
    }

    /// The underlying immutable artist entity.
    public let artist: ArtistEntity

    /// The specific role played.
    public let role: ArtistRole

    /// Connecting string (e.g. " feat. ", " & ", " with ").
    public let joinPhrase: String?

    public init(
        artist: ArtistEntity,
        role: ArtistRole = .primary,
        joinPhrase: String? = nil
    ) {
        self.artist = artist
        self.role = role
        self.joinPhrase = joinPhrase
    }
}

/// Separates presentation display string from underlying constituent artist entities.
///
/// Example:
/// Headline: "Taylor Swift feat. Post Malone"
/// Participations: [Taylor Swift (primary), Post Malone (featured)]
///
/// Prevents creating monolithic pseudo-artists like "Taylor Swift feat. Post Malone".
nonisolated public struct ArtistCredit: Hashable, Codable, Sendable {

    /// The exact credited string as presented on the release/track.
    public let headline: String

    /// The individual constituent artists and their relationships.
    public let participations: [ArtistParticipation]

    public init(
        headline: String,
        participations: [ArtistParticipation]
    ) {
        self.headline = headline
        self.participations = participations
    }

    /// Convenience initializer for a single primary artist.
    public init(single artist: ArtistEntity) {
        self.headline = artist.canonicalName
        self.participations = [
            ArtistParticipation(artist: artist, role: .primary)
        ]
    }

    /// Convenience initializer for primary + featured artist.
    public init(
        primary: ArtistEntity,
        featured: [ArtistEntity],
        customHeadline: String? = nil
    ) {
        var parts: [ArtistParticipation] = [
            ArtistParticipation(artist: primary, role: .primary, joinPhrase: featured.isEmpty ? nil : " feat. ")
        ]
        for (index, feat) in featured.enumerated() {
            let isLast = index == featured.count - 1
            parts.append(
                ArtistParticipation(artist: feat, role: .featured, joinPhrase: isLast ? nil : ", ")
            )
        }
        self.participations = parts
        if let customHeadline {
            self.headline = customHeadline
        } else if featured.isEmpty {
            self.headline = primary.canonicalName
        } else {
            let featString = featured.map(\.canonicalName).joined(separator: ", ")
            self.headline = "\(primary.canonicalName) feat. \(featString)"
        }
    }

    /// All constituent primary artists.
    public var primaryArtists: [ArtistEntity] {
        participations.filter { $0.role == .primary }.map(\.artist)
    }

    /// All constituent featured artists.
    public var featuredArtists: [ArtistEntity] {
        participations.filter { $0.role == .featured }.map(\.artist)
    }
}
