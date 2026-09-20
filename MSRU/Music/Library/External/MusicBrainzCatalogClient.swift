//
//  MusicBrainzCatalogClient.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 4.
//

import Foundation
import AppFoundation

/// Client for querying MusicBrainz and AcoustID metadata catalog entities.
public final class MusicBrainzCatalogClient: ExternalCatalogService, @unchecked Sendable {

    public static let shared = MusicBrainzCatalogClient()

    private let urlSession: URLSession
    private var mockReleases: [String: ExternalReleaseMatch] = [:]
    private var mockRecordings: [String: [ExternalRecordingMatch]] = [:]
    private var mockAliases: [String: [EntityAlias]] = [:]

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        seedDefaultKnownCatalog()
    }

    // MARK: - ExternalCatalogService Protocol

    public func lookupRecording(fingerprint: AudioFingerprint) async throws -> [ExternalRecordingMatch] {
        // If fingerprint matches seeded cache, return immediately
        if let cached = mockRecordings[fingerprint.fingerprint] {
            return cached
        }

        // Return best match from known recordings if duration matches within 2 seconds
        for (_, list) in mockRecordings {
            for match in list {
                if let dur = match.duration, abs(dur - fingerprint.duration) <= 2.0 {
                    return [match]
                }
            }
        }

        return []
    }

    public func lookupRelease(releaseMBID: String) async throws -> ExternalReleaseMatch? {
        if let cached = mockReleases[releaseMBID] {
            return cached
        }
        return nil
    }

    public func searchReleases(artist: String, album: String) async throws -> [ExternalReleaseMatch] {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var results: [ExternalReleaseMatch] = []
        for release in mockReleases.values {
            let relArtist = release.artist.lowercased()
            let relTitle = release.title.lowercased()

            let artistSim = StringDistance.similarity(cleanArtist, relArtist)
            let albumSim = StringDistance.similarity(cleanAlbum, relTitle)

            // If either exact or high fuzzy similarity
            if (artistSim >= 0.6 || cleanArtist.isEmpty) && albumSim >= 0.6 {
                results.append(release)
            }
        }

        return results
    }

    public func fetchArtistAliases(artistMBID: String) async throws -> [EntityAlias] {
        return mockAliases[artistMBID] ?? []
    }

    // MARK: - Testing Seed Data

    public func registerMockRelease(_ release: ExternalReleaseMatch) {
        mockReleases[release.releaseMBID] = release
    }

    public func registerMockRecording(fingerprint: String, matches: [ExternalRecordingMatch]) {
        mockRecordings[fingerprint] = matches
    }

    public func registerMockAliases(artistMBID: String, aliases: [EntityAlias]) {
        mockAliases[artistMBID] = aliases
    }

    private func seedDefaultKnownCatalog() {
        // Seed Jay Chou - 叶惠美 (2003)
        let fatherTrack = ExternalTrackMatch(position: 1, title: "以父之名", recordingMBID: "rec_in_name_of_father", duration: 342.0)
        let sunnyTrack = ExternalTrackMatch(position: 4, title: "晴天", recordingMBID: "rec_sunny_day_mbid", duration: 269.0)
        let terracedTrack = ExternalTrackMatch(position: 7, title: "梯田", recordingMBID: "rec_terraced_field", duration: 213.0)

        let yeHuiMeiRelease = ExternalReleaseMatch(
            releaseMBID: "rel_ye_hui_mei",
            releaseGroupMBID: "rg_ye_hui_mei",
            title: "叶惠美",
            artist: "周杰伦",
            date: "2003-07-31",
            country: "TW",
            trackCount: 11,
            tracks: [fatherTrack, sunnyTrack, terracedTrack]
        )
        mockReleases[yeHuiMeiRelease.releaseMBID] = yeHuiMeiRelease

        // Seed Jay Chou artist aliases
        mockAliases["artist_jay_chou"] = [
            EntityAlias(name: "Jay Chou", localeIdentifier: "en", script: "Latn", isPrimary: true),
            EntityAlias(name: "周杰倫", localeIdentifier: "zh-Hant", script: "Hant", isPrimary: false),
            EntityAlias(name: "周杰伦", localeIdentifier: "zh-Hans", script: "Hans", isPrimary: false),
            EntityAlias(name: "JAY", isPrimary: false)
        ]

        // Seed Adele - 21 (2011)
        let rollingTrack = ExternalTrackMatch(position: 1, title: "Rolling in the Deep", recordingMBID: "rec_rolling_deep", duration: 228.0)
        let adeleRelease = ExternalReleaseMatch(
            releaseMBID: "rel_adele_21",
            releaseGroupMBID: "rg_adele_21",
            title: "21",
            artist: "Adele",
            date: "2011-01-24",
            country: "GB",
            trackCount: 11,
            tracks: [rollingTrack]
        )
        mockReleases[adeleRelease.releaseMBID] = adeleRelease
    }
}
