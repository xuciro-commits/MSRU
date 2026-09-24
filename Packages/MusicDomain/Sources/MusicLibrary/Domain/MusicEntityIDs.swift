//
//  MusicEntityIDs.swift
//  MSRU
//
//  Type-safe music identity abstractions strictly banishing path/URL as canonical identity,
//  along with core library entries, observation claims, and storage sources.
//

import Foundation
import CryptoKit
import MusicDomain

// MARK: - Identity Protocols & Concrete IDs

public protocol MusicEntityID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible where RawValue == String {
    nonisolated init(_ value: String)
}

public extension MusicEntityID {
    nonisolated var description: String { rawValue }
    nonisolated init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.init(rawValue)
    }
}

/// Identifies a concrete audio source (e.g. local directory, SMB volume, remote service).
nonisolated public struct SourceID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> SourceID { SourceID("src_\(UUID().uuidString.lowercased())") }
    nonisolated public static let defaultLocal = SourceID("src_local_default")

    nonisolated public static func isLocalSourceID(_ id: String?) -> Bool {
        guard let id else { return false }
        return id == "local" || id == "src_local_default" || id.hasPrefix("src_local")
    }

    nonisolated public var isLocal: Bool {
        Self.isLocalSourceID(rawValue)
    }
}

/// Identifies a physical audio file asset located within a Source.
nonisolated public struct AssetID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> AssetID { AssetID("ast_\(UUID().uuidString.lowercased())") }
}

/// Identifies a canonical musical artist entity (MBID or UUID).
nonisolated public struct ArtistID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> ArtistID { ArtistID("art_\(UUID().uuidString.lowercased())") }
}

/// Identifies an abstract musical composition or work (e.g. Symphony No. 9, 晴天).
nonisolated public struct WorkID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> WorkID { WorkID("wrk_\(UUID().uuidString.lowercased())") }
}

/// Identifies a unique audio performance capture (anchored by acoustic fingerprint or MBID).
nonisolated public struct RecordingID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> RecordingID { RecordingID("rec_\(UUID().uuidString.lowercased())") }
}

/// Identifies a concrete physical or digital product issue of an album / release.
nonisolated public struct ReleaseID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> ReleaseID { ReleaseID("rel_\(UUID().uuidString.lowercased())") }
}

/// Identifies a track position / slot on a specific medium of a Release.
nonisolated public struct ReleaseTrackID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> ReleaseTrackID { ReleaseTrackID("trk_\(UUID().uuidString.lowercased())") }
}

/// Identifies a content-addressed artwork image asset (SHA256 hex).
nonisolated public struct ArtworkID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
}

/// Identifies a user library state record (favorite, rating, date added).
nonisolated public struct LibraryEntryID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> LibraryEntryID { LibraryEntryID("lib_\(UUID().uuidString.lowercased())") }
}

/// Identifies a single raw metadata observation claim from a reader.
nonisolated public struct ClaimID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> ClaimID { ClaimID("clm_\(UUID().uuidString.lowercased())") }
}

/// Identifies a group of releases (e.g. Abbey Road release group containing all CD, Vinyl, Remaster editions).
nonisolated public struct ReleaseGroupID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> ReleaseGroupID { ReleaseGroupID("rg_\(UUID().uuidString.lowercased())") }
}

/// Identifies a metadata resolution record explaining why a canonical value was chosen.
nonisolated public struct ResolutionID: MusicEntityID {
    public let rawValue: String
    nonisolated public init(_ value: String) { self.rawValue = value }
    nonisolated public static func generate() -> ResolutionID { ResolutionID("res_\(UUID().uuidString.lowercased())") }
}

// MARK: - Deterministic ID Generator

/// Deterministic, reproducible ID generation powered by SHA256 (strictly bans Swift hashValue).
nonisolated public enum DeterministicID {
    nonisolated private static func hexHash(_ input: String, prefix: String, length: Int = 16) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(prefix)_\(hex.prefix(length))"
    }

    nonisolated public static func recording(title: String, artist: String) -> RecordingID {
        let key = "\(artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        return RecordingID(hexHash(key, prefix: "rec"))
    }

    nonisolated public static func artist(name: String) -> ArtistID {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ArtistID(hexHash(key, prefix: "art"))
    }

    nonisolated public static func release(artist: String, title: String) -> ReleaseID {
        let key = "\(artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        return ReleaseID(hexHash(key, prefix: "rel"))
    }

    nonisolated public static func releaseGroup(artist: String, title: String) -> ReleaseGroupID {
        let key = "\(artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        return ReleaseGroupID(hexHash(key, prefix: "rg"))
    }

    nonisolated public static func asset(sourceID: SourceID, relativePath: String) -> AssetID {
        let key = "\(sourceID.rawValue)|\(relativePath)"
        return AssetID(hexHash(key, prefix: "ast"))
    }

    nonisolated public static func sourceRecording(sourceID: SourceID, itemID: String) -> RecordingID {
        let key = "\(sourceID.rawValue)|\(itemID)"
        return RecordingID(hexHash(key, prefix: "rec"))
    }

    nonisolated public static func sourceRelease(sourceID: SourceID, itemID: String) -> ReleaseID {
        let key = "\(sourceID.rawValue)|\(itemID)"
        return ReleaseID(hexHash(key, prefix: "rel"))
    }

    nonisolated public static func sourceReleaseGroup(sourceID: SourceID, itemID: String) -> ReleaseGroupID {
        let key = "\(sourceID.rawValue)|\(itemID)"
        return ReleaseGroupID(hexHash(key, prefix: "rg"))
    }

    nonisolated public static func sourceArtist(sourceID: SourceID, itemID: String) -> ArtistID {
        let key = "\(sourceID.rawValue)|\(itemID)"
        return ArtistID(hexHash(key, prefix: "art"))
    }

    nonisolated public static func releaseTrack(releaseID: ReleaseID, medium: Int, track: Int) -> ReleaseTrackID {
        let key = "\(releaseID.rawValue)|\(medium)|\(track)"
        return ReleaseTrackID(hexHash(key, prefix: "trk"))
    }

    nonisolated public static func libraryEntry(recordingID: RecordingID) -> LibraryEntryID {
        let key = recordingID.rawValue
        return LibraryEntryID(hexHash(key, prefix: "lib"))
    }
}

// MARK: - Library Entry

nonisolated public struct LibraryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: LibraryEntryID
    public let recordingID: RecordingID
    public let releaseTrackID: ReleaseTrackID?
    public var isFavorite: Bool
    public var rating: Int
    public var playCount: Int
    public var lastPlayedAt: Date?
    public let dateAdded: Date

    nonisolated public init(
        id: LibraryEntryID = .generate(),
        recordingID: RecordingID,
        releaseTrackID: ReleaseTrackID? = nil,
        isFavorite: Bool = false,
        rating: Int = 0,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.releaseTrackID = releaseTrackID
        self.isFavorite = isFavorite
        self.rating = rating
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.dateAdded = dateAdded
    }
}

// MARK: - Metadata Claim & User Override

nonisolated public struct MetadataClaim: Identifiable, Hashable, Codable, Sendable {
    public let id: ClaimID
    public let assetID: AssetID
    public let field: String
    public let rawValue: String
    public let sourceReader: String
    public let confidence: Double
    public let observedAt: Date

    nonisolated public init(
        id: ClaimID = .generate(),
        assetID: AssetID,
        field: String,
        rawValue: String,
        sourceReader: String,
        confidence: Double,
        observedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.field = field
        self.rawValue = rawValue
        self.sourceReader = sourceReader
        self.confidence = max(0.0, min(1.0, confidence))
        self.observedAt = observedAt
    }
}

// MARK: - Source & Capabilities

public enum SourceType: String, Codable, Sendable, CaseIterable {
    case localFolder = "local_folder"
    case networkFolder = "network_folder"
    case futureProvider = "future_provider"
    case subsonic = "subsonic"
}

nonisolated public struct SourceCapabilities: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: Int

    nonisolated public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let supportsChangeEvents       = SourceCapabilities(rawValue: 1 << 0)
    public static let supportsRecursiveScan      = SourceCapabilities(rawValue: 1 << 1)
    public static let supportsRandomAccess       = SourceCapabilities(rawValue: 1 << 2)
    public static let supportsStreaming          = SourceCapabilities(rawValue: 1 << 3)
    public static let supportsMetadataWrite      = SourceCapabilities(rawValue: 1 << 4)
    public static let supportsDelete             = SourceCapabilities(rawValue: 1 << 5)
    public static let supportsMove               = SourceCapabilities(rawValue: 1 << 6)
    public static let supportsArtwork            = SourceCapabilities(rawValue: 1 << 7)
    public static let supportsStableExternalID   = SourceCapabilities(rawValue: 1 << 8)

    public static let localFolderDefault: SourceCapabilities = [
        .supportsChangeEvents,
        .supportsRecursiveScan,
        .supportsRandomAccess,
        .supportsMetadataWrite,
        .supportsDelete,
        .supportsMove,
        .supportsArtwork,
        .supportsStableExternalID
    ]

    public static let networkFolderDefault: SourceCapabilities = [
        .supportsRecursiveScan,
        .supportsRandomAccess,
        .supportsArtwork,
        .supportsStableExternalID
    ]
}

nonisolated public struct Source: Identifiable, Hashable, Codable, Sendable {
    public let id: SourceID
    public var sourceType: SourceType
    public var uri: String
    public var displayName: String
    public var capabilities: SourceCapabilities
    public var isEnabled: Bool
    public var lastReconciledAt: Date?
    public var bookmarkData: Data?
    /// Account name for remote sources that authenticate (Subsonic).
    public var username: String?
    public let createdAt: Date
    public var updatedAt: Date

    nonisolated public init(
        id: SourceID = .generate(),
        sourceType: SourceType,
        uri: String,
        displayName: String,
        capabilities: SourceCapabilities,
        isEnabled: Bool = true,
        lastReconciledAt: Date? = nil,
        bookmarkData: Data? = nil,
        username: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.uri = uri
        self.displayName = displayName
        self.capabilities = capabilities
        self.isEnabled = isEnabled
        self.lastReconciledAt = lastReconciledAt
        self.bookmarkData = bookmarkData
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Subsonic source identity

nonisolated extension SourceID {
    /// Prefix of every SQLite source ID for a Subsonic server.
    public static let subsonicPrefix = "src_subsonic_"

    /// The server key persisted outside `sources` — Keychain accounts,
    /// artwork references and playback requests use it — e.g. `subsonic_ab12cd34`.
    public var serverKey: String {
        rawValue.hasPrefix("src_") ? String(rawValue.dropFirst(4)) : rawValue
    }

    /// Accepts either a source ID (`src_subsonic_…`) or a server key (`subsonic_…`).
    public init(serverKeyOrSourceID value: String) {
        self.init(value.hasPrefix("src_") ? value : "src_\(value)")
    }

    public static func newSubsonic() -> SourceID {
        SourceID(subsonicPrefix + UUID().uuidString.prefix(8).lowercased())
    }
}

nonisolated extension Source {
    /// Splits the pre-v6 display name shape "Name (username)".
    public static func splitLegacySubsonicDisplayName(_ value: String) -> (name: String, username: String?) {
        guard value.hasSuffix(")"), let open = value.lastIndex(of: "(") else {
            return (value, nil)
        }
        let username = value[value.index(after: open)..<value.index(before: value.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        let name = value[..<open].trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty, !name.isEmpty else { return (value, nil) }
        return (name, username)
    }
}
