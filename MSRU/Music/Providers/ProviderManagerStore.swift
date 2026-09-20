//
//  ProviderManagerStore.swift
//  MSRU
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ProviderManagerStore {

    private static let defaultsKey = "MSRU.ProviderManager.v1"

    private(set) var providers: [ManagedProvider] = []
    private(set) var testingProviderIDs: Set<UUID> = []

    private let defaults: UserDefaults?
    private let connectionResponse: @MainActor (URLRequest) async throws -> URLResponse

    init(
        defaults: UserDefaults? = .standard,
        connectionResponse: @escaping @MainActor (URLRequest) async throws -> URLResponse = { request in
            let (_, response) = try await URLSession.shared.data(for: request)
            return response
        }
    ) {
        self.defaults = defaults
        self.connectionResponse = connectionResponse
        if let data = defaults?.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([ManagedProvider].self, from: data),
           !decoded.isEmpty {
            providers = decoded
        } else {
            providers = Self.defaultProviders
            persist()
        }

        ensureOpenverseProvider()
    }


    private func ensureOpenverseProvider() {

        guard !providers
            .contains(
                where: {
                    $0.key == "openverse"
                }
            )
        else {
            return
        }

        providers.append(
            Self.openverseProvider
        )

        persist()
    }


    var orderedProviders: [ManagedProvider] {
        providers.sorted {
            if $0.priority == $1.priority {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.priority < $1.priority
        }
    }

    var playbackProviders: [ManagedProvider] {
        orderedProviders.filter { $0.capabilities.contains(.playback) }
    }

    func provider(id: UUID) -> ManagedProvider? {
        providers.first { $0.id == id }
    }

    func isTesting(id: UUID) -> Bool {
        testingProviderIDs.contains(id)
    }

    @discardableResult
    func addRemoteProvider(
        name: String,
        endpoint: String,
        capabilities: Set<ManagedProviderCapability>
    ) -> UUID {
        let nextPriority = (providers.map(\.priority).max() ?? 0) + 10
        let provider = ManagedProvider(
            key: "custom.\(UUID().uuidString.lowercased())",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: String(localized: "Custom remote service provider."),
            systemImage: "network",
            kind: .remote,
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            capabilities: capabilities,
            isEnabled: true,
            priority: nextPriority,
            isRemovable: true
        )
        providers.append(provider)
        persist()
        return provider.id
    }

    func removeCustomProvider(id: UUID) {
        guard let index = providers.firstIndex(where: { $0.id == id && $0.isRemovable }) else {
            return
        }
        providers.remove(at: index)
        persist()
    }

    func setEnabled(_ isEnabled: Bool, id: UUID) {
        guard let index = providers.firstIndex(where: { $0.id == id }) else { return }
        providers[index].isEnabled = isEnabled
        persist()
    }

    func setPriority(_ value: Int, id: UUID) {
        update(id: id) { $0.priority = max(0, value) }
    }

    func setName(_ value: String, id: UUID) {
        update(id: id) {
            guard $0.isCustom else { return }
            $0.name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func setEndpoint(_ value: String, id: UUID) {
        update(id: id) {
            guard $0.isCustom else { return }
            $0.endpoint = value.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.health = .unknown
            $0.lastTestMessage = nil
            $0.lastTestedAt = nil
        }
    }

    func setCapability(
        _ capability: ManagedProviderCapability,
        enabled: Bool,
        id: UUID
    ) {
        update(id: id) {
            guard $0.isCustom else { return }
            if enabled {
                $0.capabilities.insert(capability)
            } else {
                $0.capabilities.remove(capability)
            }
        }
    }

    func remove(id: UUID) {
        guard let item = provider(id: id), item.isRemovable else { return }
        providers.removeAll { $0.id == id }
        testingProviderIDs.remove(id)
        persist()
    }

    func updateCustomProvider(
        id: UUID,
        name: String,
        endpoint: String,
        capabilities: [ManagedProviderCapability]
    ) {
        guard let index = providers.firstIndex(where: { $0.id == id && $0.isRemovable }) else {
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        providers[index].name = trimmedName
        providers[index].endpoint = trimmedEndpoint
        providers[index].capabilities = Set(capabilities)
        providers[index].health = .unknown
        providers[index].lastTestedAt = nil
        providers[index].lastTestMessage = nil
        persist()
    }

    func moveProviders(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        providers.move(fromOffsets: offsets, toOffset: destination)
        for (index, provider) in providers.enumerated() {
            providers[index].priority = (index + 1) * 10
        }
        persist()
    }

    func testConnection(id: UUID) async {
        guard let item = provider(id: id) else { return }

        if item.kind == .builtIn && item.endpoint == nil {
            setHealth(.available, message: String(localized: "Built-in provider is available locally."), id: id)
            return
        }

        guard let endpoint = item.endpoint,
              let url = Self.validHTTPURL(endpoint)
        else {
            setHealth(.unavailable, message: String(localized: "Please enter a valid http:// or https:// URL."), id: id)
            return
        }

        testingProviderIDs.insert(id)
        defer { testingProviderIDs.remove(id) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6
        request.setValue("MSRU/0.1", forHTTPHeaderField: "User-Agent")

        do {
            let response = try await connectionResponse(request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode < 500 {
                    setHealth(
                        .available,
                        message: "\(String(localized: "Endpoint reachable")) (HTTP \(http.statusCode)).",
                        id: id
                    )
                } else {
                    setHealth(
                        .unavailable,
                        message: "\(String(localized: "Provider returned")) HTTP \(http.statusCode).",
                        id: id
                    )
                }
            } else {
                setHealth(.available, message: String(localized: "Provider endpoint is reachable."), id: id)
            }
        } catch {
            setHealth(.unavailable, message: error.localizedDescription, id: id)
        }
    }

    nonisolated static func validHTTPURL(_ value: String) -> URL? {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil
        else { return nil }
        return components.url
    }

    private func update(id: UUID, mutation: (inout ManagedProvider) -> Void) {
        guard let index = providers.firstIndex(where: { $0.id == id }) else { return }
        mutation(&providers[index])
        persist()
    }

    private func setHealth(
        _ health: ManagedProviderHealth,
        message: String,
        id: UUID
    ) {
        update(id: id) {
            $0.health = health
            $0.lastTestMessage = message
            $0.lastTestedAt = .now
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(providers) else { return }
        defaults?.set(data, forKey: Self.defaultsKey)
    }

    private static var openverseProvider:
        ManagedProvider {

        ManagedProvider(
            key:
                "openverse",
            name:
                "Openverse",
            summary:
                "Open-license audio catalog providing artwork, metadata, and direct media playback.",
            systemImage:
                "globe",
            kind:
                .builtIn,
            endpoint:
                "https://api.openverse.org/v1/audio/?q=mozart&page_size=1",
            capabilities: [
                .catalog,
                .metadata,
                .playback
            ],
            isEnabled:
                true,
            priority:
                25,
            health:
                .available,
            lastTestMessage:
                "Openverse is configured for catalog browsing and remote playback.",
            isRemovable:
                false
        )
    }


    private static var defaultProviders: [ManagedProvider] {
        [
            ManagedProvider(
                key: "local",
                name: "Local Files",
                summary: "Local playback via the MSRU playback engine.",
                systemImage: "internaldrive",
                kind: .builtIn,
                capabilities: [.playback, .library],
                isEnabled: true,
                priority: 10,
                health: .available,
                lastTestMessage: "Built-in local provider is available.",
                isRemovable: false
            ),
            ManagedProvider(
                key: "musicbrainz",
                name: "MusicBrainz",
                summary: "Metadata entity and discovery catalog.",
                systemImage: "music.note.list",
                kind: .builtIn,
                endpoint: "https://musicbrainz.org/ws/2/",
                capabilities: [.catalog, .metadata],
                isEnabled: true,
                priority: 20,
                health: .available,
                lastTestMessage: "Catalog provider configured.",
                isRemovable: false
            ),
            ManagedProvider(
                key: "jamendo",
                name: "Jamendo",
                summary: "Catalog and authorized remote playback with API access.",
                systemImage: "music.note.house",
                kind: .builtIn,
                endpoint: "https://api.jamendo.com/v3.0/",
                capabilities: [.catalog, .playback],
                isEnabled: false,
                priority: 30,
                isRemovable: false
            ),
            ManagedProvider(
                key: "apple-music",
                name: "Apple Music",
                summary: "Official Apple Music catalog, library, and native playback integration.",
                systemImage: "apple.logo",
                kind: .builtIn,
                endpoint: "https://api.music.apple.com/v1/",
                capabilities: [.catalog, .library, .playback],
                isEnabled: false,
                priority: 40,
                isRemovable: false
            )
        ]
    }
}
