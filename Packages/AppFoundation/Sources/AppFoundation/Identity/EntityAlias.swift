//
//  EntityAlias.swift
//  AppFoundation
//

import Foundation

/// A localized or alternative alias for a domain entity (e.g. artist, author, label, location).
public struct EntityAlias: Sendable, Hashable, Codable, Identifiable {

    public let id: UUID
    public let name: String
    public let localeIdentifier: String?
    public let script: String?
    public let isPrimary: Bool
    public let sortName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        localeIdentifier: String? = nil,
        script: String? = nil,
        isPrimary: Bool = false,
        sortName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.localeIdentifier = localeIdentifier
        self.script = script
        self.isPrimary = isPrimary
        self.sortName = sortName
    }
}

/// A collection of aliases anchored to an immutable canonical name for an entity.
public struct EntityAliasCollection: Sendable, Hashable, Codable {

    /// The definitive reference canonical name for the entity (e.g. from authoritative MBID).
    public let canonicalName: String

    /// Alternative names, localized scripts, and translations.
    public var aliases: [EntityAlias]

    public init(
        canonicalName: String,
        aliases: [EntityAlias] = []
    ) {
        self.canonicalName = canonicalName
        self.aliases = aliases
    }

    /// Resolves the optimal display name given an ordered list of preferred locales.
    ///
    /// Checks in order:
    /// 1. Exact locale identifier match (e.g. "zh-Hans" or "zh-Hant")
    /// 2. Language code match (e.g. "zh" or "en")
    /// 3. Primary alias fallback
    /// 4. Canonical name default
    public func displayName(preferredLocales: [Locale] = [Locale.current]) -> String {
        guard !aliases.isEmpty else { return canonicalName }

        for locale in preferredLocales {
            let identifier = locale.identifier
            let langCode = locale.language.languageCode?.identifier ?? ""

            // 1. Exact match on localeIdentifier
            if let exact = aliases.first(where: {
                guard let aliasLoc = $0.localeIdentifier else { return false }
                return aliasLoc.caseInsensitiveCompare(identifier) == .orderedSame
            }) {
                return exact.name
            }

            // 2. Prefix / Script match (e.g. "zh-Hans" vs "zh-CN")
            if !langCode.isEmpty {
                if let langMatch = aliases.first(where: {
                    guard let aliasLoc = $0.localeIdentifier else { return false }
                    return aliasLoc.lowercased().hasPrefix(langCode.lowercased())
                }) {
                    return langMatch.name
                }
            }
        }

        // 3. Primary alias fallback
        if let primary = aliases.first(where: { $0.isPrimary }) {
            return primary.name
        }

        // 4. Default to canonical
        return canonicalName
    }
}
