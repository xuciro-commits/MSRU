//
//  SourceRuntimeCoordinator.swift
//  MSRU
//
//  Single owner of media sources at runtime: the SQLite `sources` table is the
//  persisted registry; this coordinator loads it, keeps one authenticated
//  client per Subsonic server, probes capabilities before reconciling and
//  tracks each remote source's connection status.
//

import Foundation
import Observation
import AppFoundation
import SubsonicKit
import GRDB
import MusicDomain

/// Looks up the authenticated client for a source ID or server key.
public typealias SubsonicClientResolver = @Sendable (String) async -> SubsonicClient?

nonisolated public enum SubsonicClientResolvers {
    /// Resolves through the application's shared source coordinator.
    public static let shared: SubsonicClientResolver = { value in
        await SourceRuntimeCoordinator.shared.resolveSubsonicClient(serverKeyOrSourceID: value)
    }
}

/// Connection status of a remote source, observed by probes. Not persisted.
public enum RemoteSourceStatus: Hashable, Sendable {
    case unknown
    case online
    case offline(message: String)
}

@MainActor
@Observable
public final class SourceRuntimeCoordinator {
    public static let shared = SourceRuntimeCoordinator()

    /// UserDefaults key of the pre-v6 Subsonic server list, imported once.
    public static let legacySubsonicServersKey = "com.msru.subsonic.servers"
    static let legacyImportDoneKey = "com.msru.subsonic.servers.importedToSources"

    public private(set) var activeSources: [Source] = []
    public private(set) var isReconciling: [SourceID: Bool] = [:]
    public private(set) var status: [SourceID: RemoteSourceStatus] = [:]

    private let db: AppDatabase
    private let sourceRepo: SourceRepository
    private let credentialStore: any SubsonicCredentialStore
    private let legacyDefaults: UserDefaults
    @ObservationIgnored private var clients: [SourceID: SubsonicClient] = [:]
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(
        db: AppDatabase = AppDatabase.shared,
        credentialStore: any SubsonicCredentialStore = KeychainSubsonicCredentialStore(),
        legacyDefaults: UserDefaults = .standard
    ) {
        self.db = db
        self.sourceRepo = SourceRepository(db: db)
        self.credentialStore = credentialStore
        self.legacyDefaults = legacyDefaults
    }

    public var subsonicSources: [Source] {
        activeSources.filter { $0.sourceType == .subsonic }
    }

    // MARK: - Loading

    /// Loads persisted sources and registers a client per Subsonic server.
    /// Idempotent and cheap after the first call; does not touch the network.
    public func loadRemoteSources() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { @MainActor in
            await importLegacySubsonicServersIfNeeded()
            if let sources = try? await sourceRepo.loadAll() {
                replaceSources(sources)
            }
        }
        loadTask = task
        await task.value
    }

    /// Returns the authenticated client for a Subsonic source.
    public func subsonicClient(for id: SourceID) -> SubsonicClient? {
        clients[id]
    }

    /// Resolves a client from either a source ID or a server key, waiting for
    /// the initial load so lookups made during launch do not fail spuriously.
    public func resolveSubsonicClient(serverKeyOrSourceID value: String) async -> SubsonicClient? {
        await loadRemoteSources()
        return clients[SourceID(serverKeyOrSourceID: value)]
    }

    private func replaceSources(_ sources: [Source]) {
        activeSources = sources
        var next: [SourceID: SubsonicClient] = [:]
        for source in sources where source.sourceType == .subsonic {
            if let existing = clients[source.id], existing.baseURL.absoluteString == source.uri,
               existing.username == (source.username ?? "") {
                next[source.id] = existing
            } else if let client = makeClient(for: source) {
                next[source.id] = client
            }
        }
        clients = next
    }

    private func upsertActive(_ source: Source) {
        if let index = activeSources.firstIndex(where: { $0.id == source.id }) {
            activeSources[index] = source
        } else {
            activeSources.append(source)
        }
        if source.sourceType == .subsonic, clients[source.id] == nil {
            clients[source.id] = makeClient(for: source)
        }
    }

    private func makeClient(for source: Source) -> SubsonicClient? {
        guard let url = URL(string: source.uri) else { return nil }
        return SubsonicClient(
            serverID: LibrarySourceID(source.id.serverKey),
            baseURL: url,
            username: source.username ?? "",
            credentialStore: credentialStore
        )
    }

    /// Copies servers from the pre-v6 UserDefaults list into `sources` once.
    /// The legacy value is left in place as a recovery path.
    private func importLegacySubsonicServersIfNeeded() async {
        guard !legacyDefaults.bool(forKey: Self.legacyImportDoneKey) else { return }
        guard let data = legacyDefaults.data(forKey: Self.legacySubsonicServersKey) else {
            legacyDefaults.set(true, forKey: Self.legacyImportDoneKey)
            return
        }
        guard let servers = try? JSONDecoder().decode([LegacySubsonicServer].self, from: data) else {
            // Unknown shape: keep the value and retry on a later version.
            return
        }
        do {
            let existing = Set(try await sourceRepo.loadAll().map(\.id))
            for server in servers {
                guard let url = server.serverURL else { continue }
                let id = SourceID(serverKeyOrSourceID: server.id.rawValue)
                guard !existing.contains(id) else { continue }
                try await sourceRepo.insertOrUpdate(Source(
                    id: id,
                    sourceType: .subsonic,
                    uri: url.absoluteString,
                    displayName: server.name,
                    capabilities: [.supportsStreaming, .supportsArtwork, .supportsStableExternalID],
                    username: server.username
                ))
            }
            legacyDefaults.set(true, forKey: Self.legacyImportDoneKey)
        } catch {
            print("[SourceRuntimeCoordinator] Legacy server import failed: \(error)")
        }
    }

    // MARK: - Bootstrap & Probing

    /// Bootstraps all registered sources from SQLite and probes remote capabilities before reconcile.
    public func bootstrapAll() async {
        await loadRemoteSources()
        do {
            // Consolidate legacy 'local' duplicates onto the canonical defaultLocal source.
            // Identity rows are never purged here: an asset-less recording may only be
            // temporarily unavailable, and deleting it would cascade into favorites,
            // ratings and play counts. Removal happens only in `removeSource`.
            try? await db.dbWriter.write { db in
                try db.execute(sql: "UPDATE assets SET source_id = ? WHERE source_id = 'local'", arguments: [SourceID.defaultLocal.rawValue])
                try db.execute(sql: "DELETE FROM sources WHERE id = 'local'")
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

            replaceSources(sources)

            // Probe each remote source
            for source in sources where source.isEnabled && source.sourceType == .subsonic {
                await bootstrapSource(source)
            }
        } catch {
            print("[SourceRuntimeCoordinator] Bootstrap failed: \(error)")
        }
    }

    /// Probes a remote source's capabilities and records them and its status.
    public func bootstrapSource(_ source: Source) async {
        _ = await probe(source)
    }

    /// Probes a Subsonic source; returns the probed capabilities on success.
    @discardableResult
    public func probe(_ source: Source) async -> LibraryCapabilities? {
        upsertActive(source)
        guard let client = clients[source.id] else {
            status[source.id] = .offline(message: String(localized: "Invalid server address"))
            return nil
        }
        do {
            let (_, caps) = try await SubsonicCapabilityProbe().probe(client: client)
            var updated = source
            updated.capabilities = Self.sourceCapabilities(from: caps)
            updated.lastReconciledAt = Date()
            try? await sourceRepo.insertOrUpdate(updated)
            upsertActive(updated)
            status[source.id] = .online
            return caps
        } catch is CancellationError {
            return nil
        } catch {
            status[source.id] = .offline(message: error.localizedDescription)
            return nil
        }
    }

    public func probe(sourceID: SourceID) async {
        await loadRemoteSources()
        guard let source = activeSources.first(where: { $0.id == sourceID }) else { return }
        await probe(source)
    }

    static func sourceCapabilities(from caps: LibraryCapabilities) -> SourceCapabilities {
        var result: SourceCapabilities = [.supportsStreaming, .supportsStableExternalID]
        if caps.contains(.artwork) { result.insert(.supportsArtwork) }
        return result
    }

    // MARK: - Reconcile (refresh connection and sync playlists)

    public func reconcileSource(_ source: Source, client: SubsonicClient? = nil) async {
        guard isReconciling[source.id] != true else { return }
        isReconciling[source.id] = true
        defer { isReconciling[source.id] = false }

        guard await probe(source) != nil,
              let resolvedClient = client ?? clients[source.id] else { return }

        let syncService = SubsonicLibrarySyncService(
            serverID: LibrarySourceID(source.id.serverKey),
            client: resolvedClient,
            db: db
        )
        // Lightly sync playlists metadata (fast, no track scraping)
        await syncService.syncPlaylists()
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
            try await db.dbWriter.write { db in
                try Self.deleteSourceRows(id, in: db)
            }
            try? credentialStore.deletePassword(for: LibrarySourceID(id.serverKey))

            activeSources.removeAll(where: { $0.id == id })
            clients[id] = nil
            status[id] = nil
        } catch {
            print("[SourceRuntimeCoordinator] Failed to delete source \(id.rawValue): \(error)")
        }
    }

    /// Deletes a source, its assets, and only the identity rows that this
    /// removal leaves without any asset. Orphans that existed before are kept.
    nonisolated static func deleteSourceRows(_ id: SourceID, in db: Database) throws {
        let assetIDs = try String.fetchAll(db, sql: "SELECT id FROM assets WHERE source_id = ?", arguments: [id.rawValue])
        try AssetRepository.deleteAssets(assetIDs, in: db)
        try db.execute(sql: "DELETE FROM sources WHERE id = ?", arguments: [id.rawValue])
    }

    /// Verifies credentials against the server, then registers it as a source.
    /// Nothing is persisted when the probe fails.
    @discardableResult
    public func addSubsonicSource(
        name: String,
        url: URL,
        username: String,
        password: String
    ) async throws -> Source {
        await loadRemoteSources()
        let sourceID = SourceID.newSubsonic()
        let credentialKey = LibrarySourceID(sourceID.serverKey)
        try credentialStore.savePassword(password, for: credentialKey)

        let client = SubsonicClient(
            serverID: credentialKey,
            baseURL: url,
            username: username,
            credentialStore: credentialStore
        )
        let caps: LibraryCapabilities
        do {
            (_, caps) = try await SubsonicCapabilityProbe().probe(client: client)
        } catch {
            try? credentialStore.deletePassword(for: credentialKey)
            throw error
        }

        let source = Source(
            id: sourceID,
            sourceType: .subsonic,
            uri: url.absoluteString,
            displayName: name,
            capabilities: Self.sourceCapabilities(from: caps),
            isEnabled: true,
            lastReconciledAt: Date(),
            username: username
        )
        do {
            try await sourceRepo.insertOrUpdate(source)
        } catch {
            try? credentialStore.deletePassword(for: credentialKey)
            throw error
        }
        clients[sourceID] = client
        upsertActive(source)
        status[sourceID] = .online
        return source
    }
}

/// Shape of one entry in the pre-v6 UserDefaults server list.
private struct LegacySubsonicServer: Decodable {
    struct ID: Decodable { let rawValue: String }
    let id: ID
    let name: String
    let serverURL: URL?
    let username: String?
}
