//
//  MusicEntityIDs.swift
//  MSRU
//
//  Type-safe music identity abstractions strictly banishing path/URL as canonical identity.
//

import Foundation
import CryptoKit

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

    nonisolated public static func releaseTrack(releaseID: ReleaseID, medium: Int, track: Int) -> ReleaseTrackID {
        let key = "\(releaseID.rawValue)|\(medium)|\(track)"
        return ReleaseTrackID(hexHash(key, prefix: "trk"))
    }

    nonisolated public static func libraryEntry(recordingID: RecordingID) -> LibraryEntryID {
        let key = recordingID.rawValue
        return LibraryEntryID(hexHash(key, prefix: "lib"))
    }
}
