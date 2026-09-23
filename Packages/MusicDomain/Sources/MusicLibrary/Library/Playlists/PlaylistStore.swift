//
//  PlaylistStore.swift
//  MSRU
//

import Foundation
import Observation
import GRDB
import MusicDomain

nonisolated public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var trackIDs: [String]
    public var artworkReference: String?
    public var isPinned: Bool
    public var rules: SmartPlaylistRuleGroup?
    public let createdAt: Date
    public var updatedAt: Date

    public var isSmart: Bool {
        rules != nil
    }

    @MainActor
    public var artworkData: Data? {
        artworkReference.flatMap { LocalArtworkStorage.shared.loadArtwork(relativePath: $0) }
    }

    nonisolated public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        trackIDs: [String] = [],
        artworkReference: String? = nil,
        isPinned: Bool = false,
        rules: SmartPlaylistRuleGroup? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.trackIDs = trackIDs
        self.artworkReference = artworkReference
        self.isPinned = isPinned
        self.rules = rules
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    @MainActor
    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        trackIDs: [String] = [],
        artworkReference: String? = nil,
        artworkData: Data?,
        isPinned: Bool = false,
        rules: SmartPlaylistRuleGroup? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let artRef: String?
        if let artworkReference, !artworkReference.isEmpty {
            artRef = artworkReference
        } else if let artworkData, !artworkData.isEmpty {
            artRef = LocalArtworkStorage.shared.storeArtwork(artworkData)
        } else {
            artRef = nil
        }
        self.init(
            id: id,
            title: title,
            description: description,
            trackIDs: trackIDs,
            artworkReference: artRef,
            isPinned: isPinned,
            rules: rules,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public var trackCount: Int {
        trackIDs.count
    }
}

// MARK: - Playlist Repository

public protocol PlaylistRepository: Sendable {
    func loadPlaylists() async throws -> [Playlist]
    func savePlaylists(_ playlists: [Playlist]) async throws
    func applyChanges(upserting playlists: [Playlist], deleting ids: Set<UUID>) async throws
}

extension PlaylistRepository {
    public func applyChanges(upserting playlists: [Playlist], deleting ids: Set<UUID>) async throws {
        var current = try await loadPlaylists().filter { !ids.contains($0.id) }
        for playlist in playlists {
            if let index = current.firstIndex(where: { $0.id == playlist.id }) {
                current[index] = playlist
            } else {
                current.append(playlist)
            }
        }
        try await savePlaylists(current)
    }
}

// MARK: - SQLite Playlist Repository

public final class SQLitePlaylistRepository: PlaylistRepository {
    private let db: AppDatabase
    private let legacyFileURL: URL?

    public init(db: AppDatabase = .shared, legacyFileURL: URL? = nil) {
        self.db = db
        self.legacyFileURL = legacyFileURL
    }

    public convenience init(fileURL: URL) {
        self.init(db: .shared, legacyFileURL: fileURL)
    }

    public func loadPlaylists() async throws -> [Playlist] {
        try await migrateLegacyPlaylistsIfPresent()

        return try await db.reader.read { db in
            let playlistRows = try Row.fetchAll(db, sql: "SELECT * FROM playlists ORDER BY created_at DESC")
            guard !playlistRows.isEmpty else { return [] }

            let trackRows = try Row.fetchAll(db, sql: "SELECT playlist_id, track_id FROM playlist_tracks ORDER BY playlist_id ASC, position ASC")
            var tracksByPlaylistID: [String: [String]] = [:]
            for row in trackRows {
                guard let plID: String = row["playlist_id"], let trkID: String = row["track_id"] else {
                    throw PlaylistReadError.invalidRow
                }
                tracksByPlaylistID[plID, default: []].append(trkID)
            }

            var playlists: [Playlist] = []
            for row in playlistRows {
                guard let idStr: String = row["id"],
                      let id = UUID(uuidString: idStr),
                      let title: String = row["title"],
                      let createdAt: Date = row["created_at"],
                      let updatedAt: Date = row["updated_at"] else {
                    throw PlaylistReadError.invalidRow
                }
                let desc: String? = row["description"]
                let artworkRef: String? = row["artwork_reference"]
                let isPinned: Bool = row["is_pinned"] ?? false
                let trackIDs = tracksByPlaylistID[idStr] ?? []

                let rulesJSON: String? = row["rules_json"]
                let rules = try rulesJSON.map {
                    try JSONDecoder().decode(SmartPlaylistRuleGroup.self, from: Data($0.utf8))
                }

                playlists.append(Playlist(
                    id: id,
                    title: title,
                    description: desc,
                    trackIDs: trackIDs,
                    artworkReference: artworkRef,
                    isPinned: isPinned,
                    rules: rules,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                ))
            }
            return playlists
        }
    }

    public func savePlaylists(_ playlists: [Playlist]) async throws {
        let desiredIDs = Set(playlists.map(\.id))
        let existingIDs = try await db.reader.read { db in
            try Set(String.fetchAll(db, sql: "SELECT id FROM playlists").compactMap(UUID.init(uuidString:)))
        }
        try await applyChanges(upserting: playlists, deleting: existingIDs.subtracting(desiredIDs))
    }

    public func applyChanges(upserting playlists: [Playlist], deleting ids: Set<UUID>) async throws {
        guard !playlists.isEmpty || !ids.isEmpty else { return }
        try await db.dbWriter.write { db in
            for id in ids {
                try db.execute(sql: "DELETE FROM playlists WHERE id = ?", arguments: [id.uuidString])
            }
            for pl in playlists {
                let rulesJSON: String?
                if let rules = pl.rules {
                    rulesJSON = String(decoding: try JSONEncoder().encode(rules), as: UTF8.self)
                } else {
                    rulesJSON = nil
                }

                try db.execute(
                    sql: """
                    INSERT INTO playlists (id, title, description, artwork_reference, is_pinned, created_at, updated_at, rules_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        title = excluded.title,
                        description = excluded.description,
                        artwork_reference = excluded.artwork_reference,
                        is_pinned = excluded.is_pinned,
                        updated_at = excluded.updated_at,
                        rules_json = excluded.rules_json
                    """,
                    arguments: [
                        pl.id.uuidString,
                        pl.title,
                        pl.description,
                        pl.artworkReference,
                        pl.isPinned ? 1 : 0,
                        pl.createdAt,
                        pl.updatedAt,
                        rulesJSON
                    ]
                )

                let existingTracks = try String.fetchAll(
                    db, sql: "SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY position",
                    arguments: [pl.id.uuidString]
                )
                if existingTracks != pl.trackIDs {
                    try db.execute(sql: "DELETE FROM playlist_tracks WHERE playlist_id = ?",
                                   arguments: [pl.id.uuidString])
                    for (pos, trackID) in pl.trackIDs.enumerated() {
                        try db.execute(
                            sql: """
                            INSERT INTO playlist_tracks (playlist_id, track_id, position, added_at)
                            VALUES (?, ?, ?, ?)
                            """,
                            arguments: [pl.id.uuidString, trackID, pos, Date()]
                        )
                    }
                }
            }
        }
    }

    private func migrateLegacyPlaylistsIfPresent() async throws {
        guard let legacyURL = legacyFileURL ?? defaultLegacyPlaylistsURL(),
              FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        let data = try Data(contentsOf: legacyURL)

        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        let legacy = (try? isoDecoder.decode([Playlist].self, from: data))
            ?? (try? JSONDecoder().decode([Playlist].self, from: data))
        guard let legacy else { throw PlaylistMigrationError.invalidLegacyFile(legacyURL) }

        let existing = try await db.reader.read { db in
            let ids = try String.fetchAll(db, sql: "SELECT id FROM playlists")
            var tracksByID: [String: [String]] = [:]
            for id in ids {
                tracksByID[id] = try String.fetchAll(
                    db, sql: "SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY position",
                    arguments: [id]
                )
            }
            return tracksByID
        }
        for playlist in legacy {
            if let persisted = existing[playlist.id.uuidString],
               persisted != playlist.trackIDs {
                throw PlaylistMigrationError.conflictingTracks(playlist.id)
            }
        }
        let missing = legacy.filter { existing[$0.id.uuidString] == nil }
        try await applyChanges(upserting: missing, deleting: [])

        let verified = try await db.reader.read { db in
            for playlist in legacy {
                guard try Int.fetchOne(db, sql: "SELECT 1 FROM playlists WHERE id = ?",
                                       arguments: [playlist.id.uuidString]) != nil else { return false }
                let trackIDs = try String.fetchAll(
                    db, sql: "SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY position",
                    arguments: [playlist.id.uuidString]
                )
                guard trackIDs == playlist.trackIDs else { return false }
            }
            return true
        }
        guard verified else { throw PlaylistMigrationError.verificationFailed }

        let backupURL = legacyURL.appendingPathExtension("legacy.backup")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            guard try Data(contentsOf: backupURL) == data else {
                throw PlaylistMigrationError.backupConflict(backupURL)
            }
            try FileManager.default.removeItem(at: legacyURL)
        } else {
            try FileManager.default.moveItem(at: legacyURL, to: backupURL)
        }
    }

    private func defaultLegacyPlaylistsURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let msruDir = appSupport.appendingPathComponent("com.msru.cn.MSRU", isDirectory: true)
        return msruDir.appendingPathComponent("playlists.json")
    }
}

public typealias JSONPlaylistRepository = SQLitePlaylistRepository

private enum PlaylistMigrationError: LocalizedError {
    case invalidLegacyFile(URL)
    case conflictingTracks(UUID)
    case verificationFailed
    case backupConflict(URL)

    public var errorDescription: String? {
        switch self {
        case .invalidLegacyFile(let url):
            return "Unable to decode legacy playlists at \(url.path). The file was kept for recovery."
        case .conflictingTracks(let id):
            return "Legacy playlist \(id) conflicts with the database. The legacy file was kept for recovery."
        case .verificationFailed:
            return "Playlist migration verification failed. The legacy file was kept for recovery."
        case .backupConflict(let url):
            return "Playlist migration backup differs at \(url.path). Both files were kept."
        }
    }
}

private enum PlaylistReadError: LocalizedError {
    case invalidRow

    public var errorDescription: String? {
        "A stored playlist row is invalid. Existing database data was kept."
    }
}

public final class PreviewPlaylistRepository: PlaylistRepository, @unchecked Sendable {
    private var playlists: [Playlist]

    public init(playlists: [Playlist] = []) {
        self.playlists = playlists
    }

    public func loadPlaylists() async throws -> [Playlist] {
        playlists
    }

    public func savePlaylists(_ playlists: [Playlist]) async throws {
        self.playlists = playlists
    }
}

// MARK: - Playlist Store

@MainActor
@Observable
public final class PlaylistStore {

    // MARK: - Properties

    public private(set) var playlists: [Playlist] = []
    public private(set) var isLoading: Bool = false
    public private(set) var isSaving: Bool = false
    public private(set) var hasLoaded: Bool = false
    public private(set) var errorMessage: String?

    private let repository: any PlaylistRepository
    private var pendingOperation: Task<Bool, Never>?
    private var operationID: UUID?

    // MARK: - Init

    public convenience init() {
        self.init(repository: SQLitePlaylistRepository())
    }

    public init(repository: any PlaylistRepository) {
        self.repository = repository
    }

    // MARK: - Load

    public func load() async {
        _ = await serialized { [self] in
            isLoading = true
            defer { isLoading = false }
            do {
                var loaded = try await repository.loadPlaylists()
                if loaded.isEmpty {
                    let favorites = Playlist(
                        title: "Favorites",
                        description: "Your favorite tracks in one place",
                        isPinned: true
                    )
                    try await repository.applyChanges(upserting: [favorites], deleting: [])
                    loaded = [favorites]
                }
                playlists = loaded
                hasLoaded = true
                errorMessage = nil
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }

    // MARK: - Mutators

    @discardableResult
    public func createPlaylist(
        title: String,
        description: String? = nil,
        initialTrackIDs: [String] = [],
        isPinned: Bool = false,
        rules: SmartPlaylistRuleGroup? = nil
    ) async -> Playlist {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Untitled Playlist" : trimmedTitle
        let newPlaylist = Playlist(
            title: resolvedTitle,
            description: description,
            trackIDs: initialTrackIDs,
            isPinned: isPinned,
            rules: rules
        )
        _ = await mutate { current in
            var next = current
            next.insert(newPlaylist, at: 0)
            return next
        }
        return newPlaylist
    }

    @discardableResult
    public func createSmartPlaylist(
        title: String,
        description: String? = nil,
        rules: SmartPlaylistRuleGroup,
        isPinned: Bool = false
    ) async -> Playlist {
        await createPlaylist(
            title: title,
            description: description,
            initialTrackIDs: [],
            isPinned: isPinned,
            rules: rules
        )
    }

    public func resolveTracks(for playlist: Playlist, from tracks: [LocalTrack], favorites: Set<String> = []) -> [LocalTrack] {
        if let rules = playlist.rules {
            return PlaylistRuleEngine.evaluate(rules: rules, tracks: tracks, favorites: favorites)
        }
        return playlist.trackIDs.compactMap { id in
            tracks.first { $0.id == id || $0.fileURL.lastPathComponent == id || $0.fileURL.absoluteString.contains(id) }
        }
    }

    public func deletePlaylist(id: UUID) async {
        _ = await mutate { $0.filter { $0.id != id } }
    }

    public func updatePlaylist(
        id: UUID,
        title: String,
        description: String? = nil,
        isPinned: Bool? = nil,
        rules: SmartPlaylistRuleGroup? = nil,
        updateRules: Bool = false
    ) async {
        _ = await mutate { current in
            var next = current
            guard let index = next.firstIndex(where: { $0.id == id }) else { return current }
            next[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            next[index].description = description
            if let isPinned { next[index].isPinned = isPinned }
            if updateRules { next[index].rules = rules }
            next[index].updatedAt = Date()
            return next
        }
    }

    public func addTrack(_ trackID: String, to playlistID: UUID) async {
        _ = await mutate { current in
            var next = current
            guard let index = next.firstIndex(where: { $0.id == playlistID }),
                  !next[index].trackIDs.contains(trackID) else { return current }
            next[index].trackIDs.append(trackID)
            next[index].updatedAt = Date()
            return next
        }
    }

    public func addTracks(_ trackIDs: [String], to playlistID: UUID) async {
        _ = await mutate { current in
            var next = current
            guard let index = next.firstIndex(where: { $0.id == playlistID }) else { return current }
            var updated = next[index].trackIDs
            for id in trackIDs where !updated.contains(id) { updated.append(id) }
            guard updated != next[index].trackIDs else { return current }
            next[index].trackIDs = updated
            next[index].updatedAt = Date()
            return next
        }
    }

    public func removeTrack(_ trackID: String, from playlistID: UUID) async {
        _ = await mutate { current in
            var next = current
            guard let index = next.firstIndex(where: { $0.id == playlistID }),
                  next[index].trackIDs.contains(trackID) else { return current }
            next[index].trackIDs.removeAll { $0 == trackID }
            next[index].updatedAt = Date()
            return next
        }
    }

    /// Purges tracks matching the specified IDs from all playlists in a single atomic save.
    @discardableResult
    public func purgeTracks(withIDs ids: Set<String>) async -> Bool {
        guard !ids.isEmpty else { return true }
        return await mutate { current in
            var next = current
            for i in next.indices {
                let originalCount = next[i].trackIDs.count
                next[i].trackIDs.removeAll { ids.contains($0) }
                if next[i].trackIDs.count != originalCount { next[i].updatedAt = Date() }
            }
            return next
        }
    }

    public func removeTracks(at offsets: IndexSet, from playlistID: UUID) async {
        _ = await mutate { current in
            var next = current
            guard let index = next.firstIndex(where: { $0.id == playlistID }) else { return current }
            let filtered = next[index].trackIDs.enumerated()
                .filter { !offsets.contains($0.offset) }.map(\.element)
            guard filtered != next[index].trackIDs else { return current }
            next[index].trackIDs = filtered
            next[index].updatedAt = Date()
            return next
        }
    }

    public func moveTracks(from source: IndexSet, to destination: Int, in playlistID: UUID) async {
        _ = await mutate { current in
            var next = current
            guard let index = next.firstIndex(where: { $0.id == playlistID }) else { return current }
            var list = next[index].trackIDs
            guard source.allSatisfy({ list.indices.contains($0) }) else { return current }
            let itemsToMove = source.sorted().map { list[$0] }
            list = list.enumerated().filter { !source.contains($0.offset) }.map(\.element)
            let targetIndex = min(max(0, destination > (source.first ?? 0) ? destination - source.count : destination), list.count)
            list.insert(contentsOf: itemsToMove, at: targetIndex)
            guard list != next[index].trackIDs else { return current }
            next[index].trackIDs = list
            next[index].updatedAt = Date()
            return next
        }
    }

    // MARK: - Queries

    public func playlist(for id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    public func contains(trackID: String, in playlistID: UUID) -> Bool {
        playlist(for: playlistID)?.trackIDs.contains(trackID) ?? false
    }

    // MARK: - Persistence

    private func mutate(_ transform: @escaping @MainActor ([Playlist]) -> [Playlist]) async -> Bool {
        await serialized { [self] in
            let next = transform(playlists)
            let oldByID = Dictionary(uniqueKeysWithValues: playlists.map { ($0.id, $0) })
            let nextIDs = Set(next.map(\.id))
            let changed = next.filter { oldByID[$0.id] != $0 }
            let deleted = Set(oldByID.keys).subtracting(nextIDs)
            guard !changed.isEmpty || !deleted.isEmpty else { return true }
            isSaving = true
            defer { isSaving = false }
            do {
                try await repository.applyChanges(upserting: changed, deleting: deleted)
                playlists = next
                errorMessage = nil
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }

    private func serialized(_ operation: @escaping @MainActor () async -> Bool) async -> Bool {
        let previous = pendingOperation
        let id = UUID()
        let task = Task { @MainActor in
            _ = await previous?.value
            return await operation()
        }
        pendingOperation = task
        operationID = id
        let result = await task.value
        if operationID == id {
            pendingOperation = nil
            operationID = nil
        }
        return result
    }
}
