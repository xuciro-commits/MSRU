//
//  PlaylistStore.swift
//  MSRU
//

import Foundation
import Observation

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
