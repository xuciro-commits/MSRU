//
//  PlaylistStore.swift
//  MSRU
//

import Foundation
import Observation

public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var trackIDs: [String]
    public var artworkReference: String?
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public var artworkData: Data? {
        artworkReference.flatMap { LocalArtworkStorage.shared.loadArtwork(relativePath: $0) }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        trackIDs: [String] = [],
        artworkReference: String? = nil,
        artworkData: Data? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.trackIDs = trackIDs
        if let artworkReference, !artworkReference.isEmpty {
            self.artworkReference = artworkReference
        } else if let artworkData, !artworkData.isEmpty {
            self.artworkReference = LocalArtworkStorage.shared.storeArtwork(artworkData)
        } else {
            self.artworkReference = nil
        }
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

final class JSONPlaylistRepository: PlaylistRepository, @unchecked Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let msruDir = appSupport.appendingPathComponent("com.msru.cn.MSRU", isDirectory: true)
            try? FileManager.default.createDirectory(at: msruDir, withIntermediateDirectories: true)
            self.fileURL = msruDir.appendingPathComponent("playlists.json")
        }
    }

    func loadPlaylists() async throws -> [Playlist] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Playlist].self, from: data)
    }

    func savePlaylists(_ playlists: [Playlist]) async throws {
        let data = try JSONEncoder().encode(playlists)
        try data.write(to: fileURL, options: .atomic)
    }
}

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
        self.init(repository: JSONPlaylistRepository())
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
        isPinned: Bool = false
    ) async -> Playlist {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Untitled Playlist" : trimmedTitle
        let newPlaylist = Playlist(
            title: resolvedTitle,
            description: description,
            trackIDs: initialTrackIDs,
            isPinned: isPinned
        )
        playlists.insert(newPlaylist, at: 0)
        await persist()
        return newPlaylist
    }

    func deletePlaylist(id: UUID) async {
        playlists.removeAll { $0.id == id }
        await persist()
    }

    func updatePlaylist(
        id: UUID,
        title: String,
        description: String? = nil,
        isPinned: Bool? = nil
    ) async {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        playlists[index].description = description
        if let isPinned {
            playlists[index].isPinned = isPinned
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
