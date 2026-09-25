//
//  SubsonicServerStore.swift
//  MSRU
//
//  Manages configured Subsonic/OpenSubsonic servers, authentication, and status.
//

import Foundation
import Observation
import SubsonicKit
import MusicLibrary
import MusicPlayback

/// A configured Subsonic server as the settings and browse features see it.
struct SubsonicServer: Identifiable, Hashable {
    let id: SourceID
    let name: String
    let serverURL: URL?
    let username: String?
    let status: RemoteSourceStatus

    var errorMessage: String? {
        if case .offline(let message) = status { return message }
        return nil
    }
}

/// Feature-facing Subsonic operations. Servers live in the SQLite `sources`
/// table, owned at runtime by `SourceRuntimeCoordinator`; this store adds no
/// state of its own.
@MainActor
@Observable
final class SubsonicServerStore {
    let coordinator: SourceRuntimeCoordinator

    init(coordinator: SourceRuntimeCoordinator) {
        self.coordinator = coordinator
        Task { await coordinator.loadRemoteSources() }
    }

    var servers: [SubsonicServer] {
        coordinator.subsonicSources.map { source in
            SubsonicServer(
                id: source.id,
                name: source.displayName,
                serverURL: URL(string: source.uri),
                username: source.username,
                status: coordinator.status[source.id] ?? .unknown
            )
        }
    }

    func client(for sourceID: SourceID) -> SubsonicClient? {
        coordinator.subsonicClient(for: sourceID)
    }

    /// Accepts a source ID or a server key, as stored in artwork and playback references.
    func client(for sourceID: LibrarySourceID) -> SubsonicClient? {
        coordinator.subsonicClient(for: SourceID(serverKeyOrSourceID: sourceID.rawValue))
    }

    func server(for sourceID: SourceID) -> SubsonicServer? {
        servers.first { $0.id == sourceID }
    }

    func server(for sourceID: LibrarySourceID) -> SubsonicServer? {
        let id = SourceID(serverKeyOrSourceID: sourceID.rawValue)
        return servers.first { $0.id == id }
    }

    // MARK: - Testing Connection

    func testConnection(
        url: URL,
        username: String,
        password: String
    ) async throws -> (info: SubsonicServerInfo, capabilities: LibraryCapabilities) {
        let tempSourceID = LibrarySourceID("temp_\(UUID().uuidString)")
        let tempStore = InMemorySubsonicCredentialStore()
        try tempStore.savePassword(password, for: tempSourceID)

        let client = SubsonicClient(
            serverID: tempSourceID,
            baseURL: url,
            username: username,
            credentialStore: tempStore
        )
        return try await SubsonicCapabilityProbe().probe(client: client)
    }

    // MARK: - Mutations

    @discardableResult
    func addServer(
        name: String,
        url: URL,
        username: String,
        password: String
    ) async throws -> SourceID {
        try await coordinator.addSubsonicSource(
            name: name,
            url: url,
            username: username,
            password: password
        ).id
    }

    func removeServer(id: SourceID) {
        Task { await coordinator.removeSource(id: id) }
    }

    func pingServer(id: SourceID) async {
        await coordinator.probe(sourceID: id)
    }
}
