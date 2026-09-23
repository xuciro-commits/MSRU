//
//  LibraryCapabilities.swift
//  SubsonicKit
//
//  Capability set discovered or configured for a media library source.
//

import Foundation

public struct LibraryCapabilities: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let browse                 = LibraryCapabilities(rawValue: 1 << 0)
    public static let search                 = LibraryCapabilities(rawValue: 1 << 1)
    public static let artwork                = LibraryCapabilities(rawValue: 1 << 2)
    public static let lyrics                 = LibraryCapabilities(rawValue: 1 << 3)
    public static let playlistsRead          = LibraryCapabilities(rawValue: 1 << 4)
    public static let playlistsWrite         = LibraryCapabilities(rawValue: 1 << 5)
    public static let favoritesRead          = LibraryCapabilities(rawValue: 1 << 6)
    public static let favoritesWrite         = LibraryCapabilities(rawValue: 1 << 7)
    public static let streaming              = LibraryCapabilities(rawValue: 1 << 8)
    public static let downloading            = LibraryCapabilities(rawValue: 1 << 9)
    public static let scrobbling             = LibraryCapabilities(rawValue: 1 << 10)
    public static let ratings                = LibraryCapabilities(rawValue: 1 << 11)
    public static let openSubsonicExtensions = LibraryCapabilities(rawValue: 1 << 12)

    public static let localDefault: LibraryCapabilities = [
        .browse,
        .search,
        .artwork,
        .lyrics,
        .playlistsRead,
        .playlistsWrite,
        .favoritesRead,
        .favoritesWrite,
        .ratings
    ]

    public static let fullSubsonic: LibraryCapabilities = [
        .browse,
        .search,
        .artwork,
        .lyrics,
        .playlistsRead,
        .playlistsWrite,
        .favoritesRead,
        .favoritesWrite,
        .streaming,
        .downloading,
        .scrobbling,
        .ratings,
        .openSubsonicExtensions
    ]
}
