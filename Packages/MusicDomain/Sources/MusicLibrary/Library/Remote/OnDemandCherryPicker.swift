//
//  OnDemandCherryPicker.swift
//  MSRU
//
//  Cherry-picks online / public catalog items into the unified SQLite media library on demand.
//  Zero database pollution for preview playback; commits lightweight canonical records upon '+' action.
//

import Foundation
import AppFoundation
import GRDB
import MusicDomain

public final class OnDemandCherryPicker: Sendable {
    public static let shared = OnDemandCherryPicker()

    private let db: AppDatabase

    public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    /// Ingests an online catalog audio item into the local SQLite database.
    public func ingest(audio: OpenverseAudio) async throws {
        let sourceID = SourceID("src_openverse")
        let sourceRepo = SourceRepository(db: db)
        let identityRepo = IdentityRepository(db: db)
        let assetRepo = AssetRepository(db: db)

        // 1. Ensure Openverse Source exists
        let openverseSource = Source(
            id: sourceID,
            sourceType: .futureProvider,
            uri: "https://api.openverse.org",
            displayName: "Openverse",
            capabilities: [.supportsStreaming, .supportsArtwork, .supportsStableExternalID],
            isEnabled: true,
            lastReconciledAt: Date()
        )
        try? await sourceRepo.insertOrUpdate(openverseSource)

        // 2. Deterministic IDs
        let astID = DeterministicID.asset(sourceID: sourceID, relativePath: audio.id)
        let recID = DeterministicID.sourceRecording(sourceID: sourceID, itemID: audio.id)
        let trackArt = (audio.creator?.isEmpty == false) ? audio.creator! : "Unknown Artist"
        let artID = DeterministicID.sourceArtist(sourceID: sourceID, itemID: trackArt)
        let relTitle = "Openverse Single"
        let relID = DeterministicID.sourceRelease(sourceID: sourceID, itemID: relTitle)
        let rgID = DeterministicID.sourceReleaseGroup(sourceID: sourceID, itemID: relTitle)
        let trkID = DeterministicID.releaseTrack(releaseID: relID, medium: 1, track: 1)

        let duration = audio.durationMilliseconds.map { Double($0) / 1000.0 }

        // 3. Upsert entities
        try await identityRepo.batchUpsertEntities(
            artists: [(id: artID, name: trackArt)],
            recordings: [(id: recID, title: audio.title, duration: duration)],
            releaseGroups: [(id: rgID, title: relTitle)],
            releases: [(id: relID, releaseGroupID: rgID, title: relTitle, year: nil, artworkAssetID: audio.thumbnailURLString)],
            releaseTracks: [(id: trkID, releaseID: relID, trackNumber: 1, title: audio.title, duration: duration, recordingID: recID)],
            artistCredits: [
                (artistID: artID, entityType: "recording", entityID: recID.rawValue),
                (artistID: artID, entityType: "release", entityID: relID.rawValue)
            ]
        )

        // 4. Asset records
        let assetRecord = PersistedAssetRecord(
            id: astID,
            sourceID: sourceID,
            relativePath: audio.id,
            fileSize: 0,
            mtime: Date().timeIntervalSince1970,
            format: "MP3",
            bitrateKbps: 128,
            duration: duration ?? 0,
            recordingID: recID
        )
        try await assetRepo.batchUpsert([assetRecord])

        let streamAsset = AssetRepository.PersistedStreamAssetRecord(
            assetID: astID,
            providerID: "openverse",
            remoteItemID: audio.id,
            streamURL: audio.mediaURLString,
            isHLS: false,
            expiresAt: nil
        )
        try await assetRepo.batchUpsertStreamAssets([streamAsset])

        // 5. Add to user library_entries
        try await db.dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO library_entries (id, recording_id, is_favorite, date_added)
                VALUES (?, ?, 0, ?)
                """,
                arguments: [DeterministicID.libraryEntry(recordingID: recID).rawValue, recID.rawValue, Date()]
            )
        }
    }

    /// Checks if an item is already ingested in SQLite
    public func isIngested(itemID: String) async -> Bool {
        let sourceID = SourceID("src_openverse")
        let astID = DeterministicID.asset(sourceID: sourceID, relativePath: itemID)
        return (try? await db.reader.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM assets WHERE id = ?)", arguments: [astID.rawValue])
        }) ?? false
    }
}
