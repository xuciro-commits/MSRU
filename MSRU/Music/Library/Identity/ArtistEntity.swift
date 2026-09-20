//
//  ArtistEntity.swift
//  MSRU
//

import Foundation
import AppFoundation

/// An immutable identity representing a musical artist, band, orchestra, or composer.
///
/// Anchored by a stable identifier (e.g. MusicBrainz MBID).
/// Displays localized names according to `aliasCollection` and user locale.
nonisolated public struct ArtistEntity: Identifiable, Hashable, Codable, Sendable {

    /// Stable identity (e.g. MusicBrainz MBID: "0d79768b-9842-4215-b44c-0062c66f50b2")
    public let id: String

    /// Localized name aliases and canonical name.
    public var aliasCollection: EntityAliasCollection

    /// Disambiguation comment (e.g. "Taiwanese singer-songwriter", "UK indie rock band").
    public var disambiguation: String?

    /// Two-letter country code or territory.
    public var country: String?

    /// Activity date start (e.g. "1979-01-18").
    public var beginDate: String?

    /// Activity date end if disbanded or deceased.
    public var endDate: String?

    public init(
        id: String,
        canonicalName: String,
        aliases: [EntityAlias] = [],
        disambiguation: String? = nil,
        country: String? = nil,
        beginDate: String? = nil,
        endDate: String? = nil
    ) {
        self.id = id
        self.aliasCollection = EntityAliasCollection(
            canonicalName: canonicalName,
            aliases: aliases
        )
        self.disambiguation = disambiguation
        self.country = country
        self.beginDate = beginDate
        self.endDate = endDate
    }

    /// The definitive reference canonical name for the artist.
    public var canonicalName: String {
        aliasCollection.canonicalName
    }

    /// Resolves the optimal display name given preferred locales (e.g. zh-Hans -> 周杰伦, en -> Jay Chou).
    public func displayName(preferredLocales: [Locale] = [Locale.current]) -> String {
        aliasCollection.displayName(preferredLocales: preferredLocales)
    }
}
