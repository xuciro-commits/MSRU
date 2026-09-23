//
//  Fakes.swift
//  MSRUTests
//
//  Deterministic in-memory fakes for external catalog and fingerprint services (strictly 100% offline).
//

import Foundation
import AppFoundation
@testable import MSRU
import MusicDomain

final class FakeCatalogService: ExternalCatalogService, @unchecked Sendable {
    var recordings: [String: [ExternalRecordingMatch]] = [:]
    var releases: [String: ExternalReleaseMatch] = [:]
    var searchResults: [(artist: String, album: String, results: [ExternalReleaseMatch])] = []
    var artistAliases: [String: [EntityAlias]] = [:]

    init() {}

    func lookupRecording(fingerprint: AcousticFingerprint) async throws -> [ExternalRecordingMatch] {
        if let matches = recordings[fingerprint.fingerprint] {
            return matches
        }
        for (_, list) in recordings {
            for match in list {
                if let dur = match.duration, abs(dur - fingerprint.duration) <= 2.0 {
                    return [match]
                }
            }
        }
        return []
    }

    func lookupRelease(releaseMBID: String) async throws -> ExternalReleaseMatch? {
        releases[releaseMBID]
    }

    func searchReleases(artist: String, album: String) async throws -> [ExternalReleaseMatch] {
        let normArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for item in searchResults {
            if item.artist.lowercased() == normArtist && item.album.lowercased() == normAlbum {
                return item.results
            }
        }
        return []
    }

    func fetchArtistAliases(artistMBID: String) async throws -> [EntityAlias] {
        artistAliases[artistMBID] ?? []
    }
}

final class FakeFingerprinter: AcousticFingerprintExtracting, Sendable {
    let stubbedFingerprint: AcousticFingerprint

    init(
        value: String = "fake_fingerprint_base64_data",
        duration: Double = 180.0,
        algorithm: String = "chromaprint-v1"
    ) {
        self.stubbedFingerprint = AcousticFingerprint(value: value, duration: duration, algorithm: algorithm)
    }

    func generateFingerprint(for fileURL: URL) async throws -> AcousticFingerprint {
        stubbedFingerprint
    }
}
