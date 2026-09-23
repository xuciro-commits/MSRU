//
//  SourceRuntimeCoordinator.swift
//  MSRU
//
//  Coordinates lifecycle, capability probing, and reconciliation of all media library sources.
//  Ensures capability probe executes during bootstrap prior to any synchronization.
//

import Foundation
import Observation
import AppFoundation
import MediaLibrary
import SubsonicKit
import GRDB

@MainActor
@Observable
public final class SourceRuntimeCoordinator {
    public static let shared = SourceRuntimeCoordinator()

    public private(set) var activeSources: [Source] = []
    public private(set) var isReconciling: [SourceID: Bool] = [:]

    private let db: AppDatabase
    private let sourceRepo: SourceRepository
    private let credentialStore: any SubsonicCredentialStore

    public init(
        db: AppDatabase = AppDatabase.shared,
        credentialStore: any SubsonicCredentialStore = KeychainSubsonicCredentialStore()
    ) {
        self.db = db
        self.sourceRepo = SourceRepository(db: db)
        self.credentialStore = credentialStore
    }

    // MARK: - Bootstrap & Probing (Step 1 & Step 2)

    /// Bootstraps all registered sources from SQLite and probes remote capabilities before reconcile.
    public func bootstrapAll() async {
        do {
            // Clean up legacy 'local' duplicates and migrate assets to canonical defaultLocal
            try? await db.dbWriter.write { db in
                try db.execute(sql: "UPDATE assets SET source_id = ? WHERE source_id = 'local'", arguments: [SourceID.defaultLocal.rawValue])
                try db.execute(sql: "DELETE FROM sources WHERE id = 'local'")

                // Purge disconnected orphan records to maintain strict library integrity
                try db.execute(sql: "DELETE FROM release_tracks WHERE recording_id NOT IN (SELECT id FROM recordings)")
                try db.execute(sql: "DELETE FROM recordings WHERE id NOT IN (SELECT recording_id FROM assets)")
                try db.execute(sql: "DELETE FROM releases WHERE id NOT IN (SELECT release_id FROM release_tracks)")
                try db.execute(sql: "DELETE FROM artist_credits WHERE entity_id NOT IN (SELECT id FROM recordings) AND entity_id NOT IN (SELECT id FROM releases)")
                try db.execute(sql: "DELETE FROM artists WHERE id NOT IN (SELECT artist_id FROM artist_credits)")
            }

            var sources = try await sourceRepo.loadAll()

            // Ensure canonical Local Source is registered
            let localSourceID = SourceID.defaultLocal
            if !sources.contains(where: { $0.id == localSourceID }) {
                let localSource = Source(
                    id: localSourceID,
                    sourceType: .localFolder,
                    uri: "file://local",
                    displayName: String(localized: "Local Files"),
                    capabilities: SourceCapabilities.localFolderDefault,
                    isEnabled: true,
                    lastReconciledAt: Date()
                )
                try? await sourceRepo.insertOrUpdate(localSource)
                sources.append(localSource)
            }

            self.activeSources = sources

            // Probe and reconcile each remote source
            for source in sources where source.isEnabled && !SourceID.isLocalSourceID(source.id.rawValue) {
                await bootstrapSource(source)
            }
        } catch {
            print("[SourceRuntimeCoordinator] Bootstrap failed: \(error)")
        }
    }

    /// Bootstraps a single source: executes Capability Probe first, updates SQLite, then triggers reconcile.
    public func bootstrapSource(_ source: Source) async {
        guard let url = URL(string: source.uri) else { return }

        let libSourceID = LibrarySourceID(source.id.rawValue.replacingOccurrences(of: "src_", with: ""))
        let username = source.displayName.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let client = SubsonicClient(
            serverID: libSourceID,
            baseURL: url,
            username: username,
            credentialStore: credentialStore
        )

        // Step 2: Capability Probe BEFORE Reconcile
        let probe = SubsonicCapabilityProbe()
        do {
            let (_, caps) = try await probe.probe(client: client)

            var sourceCaps: SourceCapabilities = [.supportsStreaming]
            if caps.contains(.artwork) { sourceCaps.insert(.supportsArtwork) }
            sourceCaps.insert(.supportsStableExternalID)

            var updated = source
            updated.capabilities = sourceCaps
            updated.lastReconciledAt = Date()
            try await sourceRepo.insertOrUpdate(updated)

            if let idx = activeSources.firstIndex(where: { $0.id == source.id }) {
                activeSources[idx] = updated
            }

            // Mark source as online and updated
            print("[SourceRuntimeCoordinator] Capability probe succeeded for \(source.displayName)")
        } catch is CancellationError {
            // Cooperative cancellation
        } catch {
            print("[SourceRuntimeCoordinator] Capability probe failed for \(source.displayName): \(error)")
        }
    }

    // MARK: - Reconcile (Step 3: Refresh connection and sync playlists)

    public func reconcileSource(_ source: Source, client: SubsonicClient? = nil) async {
        guard isReconciling[source.id] != true else { return }
        isReconciling[source.id] = true
        defer { isReconciling[source.id] = false }

        let libSourceID = LibrarySourceID(source.id.rawValue.replacingOccurrences(of: "src_", with: ""))
        let resolvedClient: SubsonicClient
        if let client {
            resolvedClient = client
        } else {
            guard let url = URL(string: source.uri) else { return }
            let username = source.displayName.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            resolvedClient = SubsonicClient(
                serverID: libSourceID,
                baseURL: url,
                username: username,
                credentialStore: credentialStore
            )
        }

        let syncService = SubsonicLibrarySyncService(
            serverID: libSourceID,
            client: resolvedClient,
            db: db
        )

        do {
            // 1. Probe & refresh server status
            let probe = SubsonicCapabilityProbe()
            let (_, caps) = try await probe.probe(client: resolvedClient)

            var sourceCaps: SourceCapabilities = [.supportsStreaming]
            if caps.contains(.artwork) { sourceCaps.insert(.supportsArtwork) }
            sourceCaps.insert(.supportsStableExternalID)

            var updated = source
            updated.capabilities = sourceCaps
            updated.lastReconciledAt = Date()
            try? await sourceRepo.insertOrUpdate(updated)
            if let idx = activeSources.firstIndex(where: { $0.id == source.id }) {
                activeSources[idx] = updated
            }

            // 2. Lightly sync playlists metadata (fast, ~100ms, no track scraping)
            await syncService.syncPlaylists()
        } catch is CancellationError {
            // Cooperative task cancellation, ignore
        } catch {
            print("[SourceRuntimeCoordinator] Reconcile failed for \(source.displayName): \(error)")
        }
    }

    // MARK: - Source Statistics & Mutations

    public func fetchSourceStats(sourceID: SourceID) async -> (tracks: Int, albums: Int, playlists: Int) {
        do {
            return try await db.reader.read { db in
                let trackCount: Int
                let albumCount: Int
                let playlistCount: Int

                if SourceID.isLocalSourceID(sourceID.rawValue) {
                    trackCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets WHERE source_id = 'src_local_default' OR source_id = 'local' OR source_id IS NULL") ?? 0
                    albumCount = try Int.fetchOne(db, sql: """
                        SELECT COUNT(DISTINCT r.id)
                        FROM releases r
                        JOIN release_tracks rt ON rt.release_id = r.id
                        JOIN assets a ON a.recording_id = rt.recording_id
                        WHERE a.source_id = 'src_local_default' OR a.source_id = 'local' OR a.source_id IS NULL
                    """) ?? 0
                    playlistCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playlists WHERE description NOT LIKE '%Subsonic%' AND description NOT LIKE '%极空间%'") ?? 0
                } else {
                    trackCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets WHERE source_id = ?", arguments: [sourceID.rawValue]) ?? 0
                    albumCount = try Int.fetchOne(db, sql: """
                        SELECT COUNT(DISTINCT r.id)
                        FROM releases r
                        JOIN release_tracks rt ON rt.release_id = r.id
                        JOIN assets a ON a.recording_id = rt.recording_id
                        WHERE a.source_id = ?
                    """, arguments: [sourceID.rawValue]) ?? 0
                    playlistCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playlists WHERE description LIKE ? OR description LIKE '%Subsonic%' OR description LIKE '%极空间%'", arguments: ["%\(sourceID.rawValue)%"]) ?? 0
                }

                return (tracks: trackCount, albums: albumCount, playlists: playlistCount)
            }
        } catch {
            return (tracks: 0, albums: 0, playlists: 0)
        }
    }

    public func removeSource(id: SourceID) async {
        do {
            try await sourceRepo.delete(id: id)
            let libSourceID = LibrarySourceID(id.rawValue.replacingOccurrences(of: "src_", with: ""))
            try? credentialStore.deletePassword(for: libSourceID)

            try await db.dbWriter.write { db in
                try db.execute(sql: "DELETE FROM stream_assets WHERE asset_id IN (SELECT id FROM assets WHERE source_id = ?)", arguments: [id.rawValue])
                try db.execute(sql: "DELETE FROM assets WHERE source_id = ?", arguments: [id.rawValue])
            }

            activeSources.removeAll(where: { $0.id == id })
        } catch {
            print("[SourceRuntimeCoordinator] Failed to delete source \(id.rawValue): \(error)")
        }
    }

    @discardableResult
    public func addSubsonicSource(
        name: String,
        url: URL,
        username: String,
        password: String
    ) async throws -> Source {
        let rawID = "subsonic_\(UUID().uuidString.prefix(8).lowercased())"
        let libSourceID = LibrarySourceID(rawID)
        let sourceID = SourceID("src_\(rawID)")

        try credentialStore.savePassword(password, for: libSourceID)

        let source = Source(
            id: sourceID,
            sourceType: .futureProvider,
            uri: url.absoluteString,
            displayName: "\(name) (\(username))",
            capabilities: [.supportsStreaming, .supportsArtwork, .supportsStableExternalID],
            isEnabled: true,
            lastReconciledAt: nil
        )

        try await sourceRepo.insertOrUpdate(source)
        if !activeSources.contains(where: { $0.id == source.id }) {
            activeSources.append(source)
        }

        Task {
            await bootstrapSource(source)
        }

        return source
    }
}
