//
//  PlaylistStore.swift
//  MSRU
//

import Foundation
import Observation
import GRDB

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

protocol PlaylistRepository: Sendable {
    func loadPlaylists() async throws -> [Playlist]
    func savePlaylists(_ playlists: [Playlist]) async throws
}

// MARK: - SQLite Playlist Repository

final class SQLitePlaylistRepository: PlaylistRepository {
    private let db: AppDatabase
    private let legacyFileURL: URL?

    init(db: AppDatabase = .shared, legacyFileURL: URL? = nil) {
        self.db = db
        self.legacyFileURL = legacyFileURL
    }

    convenience init(fileURL: URL) {
        self.init(db: .shared, legacyFileURL: fileURL)
    }

    func loadPlaylists() async throws -> [Playlist] {
        await migrateLegacyPlaylistsIfPresent()

        return try await db.reader.read { db in
            let playlistRows = try Row.fetchAll(db, sql: "SELECT * FROM playlists ORDER BY created_at DESC")
            guard !playlistRows.isEmpty else { return [] }

            let trackRows = try Row.fetchAll(db, sql: "SELECT playlist_id, track_id FROM playlist_tracks ORDER BY playlist_id ASC, position ASC")
            var tracksByPlaylistID: [String: [String]] = [:]
            for row in trackRows {
                guard let plID: String = row["playlist_id"], let trkID: String = row["track_id"] else { continue }
                tracksByPlaylistID[plID, default: []].append(trkID)
            }

            var playlists: [Playlist] = []
            for row in playlistRows {
                guard let idStr: String = row["id"],
                      let id = UUID(uuidString: idStr),
                      let title: String = row["title"],
                      let createdAt: Date = row["created_at"],
                      let updatedAt: Date = row["updated_at"] else { continue }
                let desc: String? = row["description"]
                let artworkRef: String? = row["artwork_reference"]
                let isPinned: Bool = row["is_pinned"] ?? false
                let trackIDs = tracksByPlaylistID[idStr] ?? []

                let rulesJSON: String? = row["rules_json"]
                let rules: SmartPlaylistRuleGroup? = rulesJSON.flatMap {
                    try? JSONDecoder().decode(SmartPlaylistRuleGroup.self, from: Data($0.utf8))
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

    func savePlaylists(_ playlists: [Playlist]) async throws {
        try await db.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM playlists")

            for pl in playlists {
                let rulesJSON: String?
                if let rules = pl.rules,
                   let data = try? JSONEncoder().encode(rules),
                   let jsonString = String(data: data, encoding: .utf8) {
                    rulesJSON = jsonString
                } else {
                    rulesJSON = nil
                }

                try db.execute(
                    sql: """
                    INSERT INTO playlists (id, title, description, artwork_reference, is_pinned, created_at, updated_at, rules_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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

                for (pos, trackID) in pl.trackIDs.enumerated() {
                    try db.execute(
                        sql: """
                        INSERT INTO playlist_tracks (playlist_id, track_id, position, added_at)
                        VALUES (?, ?, ?, ?)
                        """,
                        arguments: [
                            pl.id.uuidString,
                            trackID,
                            pos,
                            Date()
                        ]
                    )
                }
            }
        }
    }

    private func migrateLegacyPlaylistsIfPresent() async {
        guard let legacyURL = legacyFileURL ?? defaultLegacyPlaylistsURL(),
              FileManager.default.fileExists(atPath: legacyURL.path),
              let data = try? Data(contentsOf: legacyURL),
              !data.isEmpty else { return }

        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        let legacy = (try? isoDecoder.decode([Playlist].self, from: data))
            ?? (try? JSONDecoder().decode([Playlist].self, from: data))
        if let legacy, !legacy.isEmpty {
            try? await savePlaylists(legacy)
        }
        try? FileManager.default.removeItem(at: legacyURL)
    }

    private func defaultLegacyPlaylistsURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let msruDir = appSupport.appendingPathComponent("com.msru.cn.MSRU", isDirectory: true)
        return msruDir.appendingPathComponent("playlists.json")
    }
}

typealias JSONPlaylistRepository = SQLitePlaylistRepository

final class PreviewPlaylistRepository: PlaylistRepository, @unchecked Sendable {
    private var playlists: [Playlist]

    init(playlists: [Playlist] = []) {
        self.playlists = playlists
    }

    func loadPlaylists() async throws -> [Playlist] {
        playlists
    }

    func savePlaylists(_ playlists: [Playlist]) async throws {
        self.playlists = playlists
    }
}

// MARK: - Playlist Store

@MainActor
@Observable
final class PlaylistStore {

    // MARK: - Properties

    private(set) var playlists: [Playlist] = []
    private(set) var isLoading: Bool = false
    private(set) var isSaving: Bool = false
    private(set) var hasLoaded: Bool = false
    private(set) var errorMessage: String?

    private let repository: any PlaylistRepository

    // MARK: - Init

    convenience init() {
        self.init(repository: SQLitePlaylistRepository())
    }

    init(repository: any PlaylistRepository) {
        self.repository = repository
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            playlists = try await repository.loadPlaylists()
            hasLoaded = true
            errorMessage = nil

            // If store is empty, seed a default "Favorites" playlist
            if playlists.isEmpty {
                let defaultFavorites = Playlist(
                    title: "Favorites",
                    description: "Your favorite tracks in one place",
                    isPinned: true
                )
                playlists.append(defaultFavorites)
                try? await repository.savePlaylists(playlists)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutators

    @discardableResult
    func createPlaylist(
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
        playlists.insert(newPlaylist, at: 0)
        await persist()
        return newPlaylist
    }

    @discardableResult
    func createSmartPlaylist(
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

    func resolveTracks(for playlist: Playlist, from tracks: [LocalTrack], favorites: Set<String> = []) -> [LocalTrack] {
        if let rules = playlist.rules {
            return PlaylistRuleEngine.evaluate(rules: rules, tracks: tracks, favorites: favorites)
        }
        return playlist.trackIDs.compactMap { id in
            tracks.first { $0.id == id || $0.fileURL.lastPathComponent == id || $0.fileURL.absoluteString.contains(id) }
        }
    }

    func deletePlaylist(id: UUID) async {
        playlists.removeAll { $0.id == id }
        await persist()
    }

    func updatePlaylist(
        id: UUID,
        title: String,
        description: String? = nil,
        isPinned: Bool? = nil,
        rules: SmartPlaylistRuleGroup? = nil,
        updateRules: Bool = false
    ) async {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        playlists[index].description = description
        if let isPinned {
            playlists[index].isPinned = isPinned
        }
        if updateRules {
            playlists[index].rules = rules
        }
        playlists[index].updatedAt = Date()
        await persist()
    }

    func addTrack(_ trackID: String, to playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[index].trackIDs.contains(trackID) {
            playlists[index].trackIDs.append(trackID)
            playlists[index].updatedAt = Date()
            await persist()
        }
    }

    func addTracks(_ trackIDs: [String], to playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        var updated = playlists[index].trackIDs
        for id in trackIDs {
            if !updated.contains(id) {
                updated.append(id)
            }
        }
        playlists[index].trackIDs = updated
        playlists[index].updatedAt = Date()
        await persist()
    }

    func removeTrack(_ trackID: String, from playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.removeAll { $0 == trackID }
        playlists[index].updatedAt = Date()
        await persist()
    }

    /// Purges tracks matching the specified IDs from all playlists in a single atomic save.
    func purgeTracks(withIDs ids: Set<String>) async {
        guard !ids.isEmpty else { return }
        var changed = false
        for i in playlists.indices {
            let originalCount = playlists[i].trackIDs.count
            playlists[i].trackIDs.removeAll { ids.contains($0) }
            if playlists[i].trackIDs.count != originalCount {
                playlists[i].updatedAt = Date()
                changed = true
            }
        }
        if changed {
            await persist()
        }
    }

    func removeTracks(at offsets: IndexSet, from playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs = playlists[index].trackIDs
            .enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        playlists[index].updatedAt = Date()
        await persist()
    }

    func moveTracks(from source: IndexSet, to destination: Int, in playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        var list = playlists[index].trackIDs
        let itemsToMove = source.sorted().map { list[$0] }
        list = list.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let targetIndex = min(max(0, destination > (source.first ?? 0) ? destination - source.count : destination), list.count)
        list.insert(contentsOf: itemsToMove, at: targetIndex)
        playlists[index].trackIDs = list
        playlists[index].updatedAt = Date()
        await persist()
    }

    // MARK: - Queries

    func playlist(for id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    func contains(trackID: String, in playlistID: UUID) -> Bool {
        playlist(for: playlistID)?.trackIDs.contains(trackID) ?? false
    }

    // MARK: - Persistence

    private func persist() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.savePlaylists(playlists)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
