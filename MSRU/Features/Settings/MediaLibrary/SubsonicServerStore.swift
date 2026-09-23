//
//  SubsonicServerStore.swift
//  MSRU
//
//  Manages configured Subsonic/OpenSubsonic servers, authentication, and status.
//

import Foundation
import Observation
import MediaLibrary
import SubsonicKit
import MusicLibrary
import MusicPlayback

@MainActor
@Observable
final class SubsonicServerStore {
    private(set) var servers: [LibrarySource] = []
    private let credentialStore: any SubsonicCredentialStore
    private let registry: LibraryProviderRegistry
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "com.msru.subsonic.servers"

    init(
        credentialStore: any SubsonicCredentialStore = KeychainSubsonicCredentialStore(),
        registry: LibraryProviderRegistry = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.credentialStore = credentialStore
        self.registry = registry
        self.userDefaults = userDefaults
        loadServers()
    }

    private func loadServers() {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let list = try? JSONDecoder().decode([LibrarySource].self, from: data) else {
            return
        }
        self.servers = list

        for server in list {
            guard let url = server.serverURL, let username = server.username else { continue }
            let client = SubsonicClient(
                serverID: server.id,
                baseURL: url,
                username: username,
                credentialStore: credentialStore
            )
            let provider = SubsonicLibraryProvider(
                sourceID: server.id,
                sourceName: server.name,
                serverURL: url,
                username: username,
                client: client
            )
            registry.register(provider)
        }
    }

    private var clients: [LibrarySourceID: SubsonicClient] = [:]

    func client(for sourceID: LibrarySourceID) -> SubsonicClient? {
        if let existing = clients[sourceID] {
            return existing
        }
        guard let server = servers.first(where: {
            $0.id == sourceID ||
            $0.id.rawValue == sourceID.rawValue ||
            "src_\($0.id.rawValue)" == sourceID.rawValue ||
            $0.id.rawValue == sourceID.rawValue.replacingOccurrences(of: "src_", with: "")
        }),
        let url = server.serverURL,
        let username = server.username else {
            return nil
        }
        let client = SubsonicClient(
            serverID: server.id,
            baseURL: url,
            username: username,
            credentialStore: credentialStore
        )
        clients[server.id] = client
        return client
    }

    func server(for sourceID: LibrarySourceID) -> LibrarySource? {
        servers.first(where: {
            $0.id == sourceID ||
            $0.id.rawValue == sourceID.rawValue ||
            "src_\($0.id.rawValue)" == sourceID.rawValue ||
            $0.id.rawValue == sourceID.rawValue.replacingOccurrences(of: "src_", with: "")
        })
    }

    private func persistServers() {
        if let data = try? JSONEncoder().encode(servers) {
            userDefaults.set(data, forKey: userDefaultsKey)
        }
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

        let probe = SubsonicCapabilityProbe()
        return try await probe.probe(client: client)
    }

    // MARK: - Add Server

    @discardableResult
    func addServer(
        name: String,
        url: URL,
        username: String,
        password: String
    ) async throws -> LibrarySource {
        let sourceID = LibrarySourceID("subsonic_\(UUID().uuidString.prefix(8).lowercased())")

        // 1. Save password to Keychain
        try credentialStore.savePassword(password, for: sourceID)

        // 2. Initialize client and probe capabilities
        let client = SubsonicClient(
            serverID: sourceID,
            baseURL: url,
            username: username,
            credentialStore: credentialStore
        )

        let probe = SubsonicCapabilityProbe()
        let (_, capabilities) = try await probe.probe(client: client)

        // 3. Create LibrarySource record
        let source = LibrarySource(
            id: sourceID,
            name: name,
            kind: .subsonic,
            capabilities: capabilities,
            state: .online,
            serverURL: url,
            username: username,
            lastSyncAt: Date()
        )

        servers.append(source)
        persistServers()

        // 4. Register provider
        let provider = SubsonicLibraryProvider(
            sourceID: sourceID,
            sourceName: name,
            serverURL: url,
            username: username,
            client: client
        )
        registry.register(provider)

        // 5. Synchronize with SQLite SourceRepository & Coordinator
        let fullSourceID = SourceID("src_\(sourceID.rawValue)")
        let dbSource = Source(
            id: fullSourceID,
            sourceType: .futureProvider,
            uri: url.absoluteString,
            displayName: "\(name) (\(username))",
            capabilities: [.supportsStreaming, .supportsArtwork, .supportsStableExternalID],
            isEnabled: true,
            lastReconciledAt: Date()
        )
        try? await SourceRepository().insertOrUpdate(dbSource)
        Task {
            await SourceRuntimeCoordinator.shared.bootstrapSource(dbSource)
        }

        return source
    }

    // MARK: - Remove Server

    func removeServer(id: LibrarySourceID) {
        try? credentialStore.deletePassword(for: id)
        registry.remove(id)
        servers.removeAll(where: { $0.id == id })
        persistServers()

        let fullSourceID = SourceID("src_\(id.rawValue)")
        Task {
            await SourceRuntimeCoordinator.shared.removeSource(id: fullSourceID)
        }
    }

    // MARK: - Refresh Status

    func pingServer(id: LibrarySourceID) async {
        guard let index = servers.firstIndex(where: { $0.id == id }),
              let url = servers[index].serverURL,
              let username = servers[index].username else {
            return
        }

        let client = SubsonicClient(
            serverID: id,
            baseURL: url,
            username: username,
            credentialStore: credentialStore
        )

        do {
            let probe = SubsonicCapabilityProbe()
            let (_, caps) = try await probe.probe(client: client)
            servers[index].capabilities = caps
            servers[index].state = .online
            servers[index].errorMessage = nil
        } catch let err as RemoteLibraryError {
            servers[index].state = .offline
            servers[index].errorMessage = err.localizedDescription
        } catch {
            servers[index].state = .offline
            servers[index].errorMessage = error.localizedDescription
        }
        persistServers()
    }
}
