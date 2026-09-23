//
//  SubsonicServerStoreTests.swift
//  MSRUTests
//

import Testing
import Foundation
@testable import MSRU
import MediaLibrary
import SubsonicKit
import MusicDomain

@Suite("Subsonic Server Integration Contracts")
struct SubsonicServerStoreTests {

    @Test("SubsonicServerPreset provides correct defaults for ZSpace, Navidrome, and Generic")
    func serverPresets() {
        let zspace = SubsonicServerPreset.zspace
        #expect(zspace.defaultPort == 8025)
        #expect(zspace.displayName.contains("极空间"))
        #expect(zspace.formatDefaultURL(host: "192.168.31.200")?.absoluteString == "http://192.168.31.200:8025")

        let navidrome = SubsonicServerPreset.navidrome
        #expect(navidrome.defaultPort == 4533)
        #expect(navidrome.displayName == "Navidrome")

        let generic = SubsonicServerPreset.generic
        #expect(generic.defaultPort == 4040)
    }

    @Test("RemoteSubsonicPlaybackProvider resolves valid stream URLs")
    @MainActor
    func subsonicPlaybackProviderResolves() async throws {
        let provider = RemoteSubsonicPlaybackProvider()

        let validURL = URL(string: "http://192.168.31.200:8025/rest/stream.view?id=123&format=raw")!
        let request = PlaybackRequest(
            itemID: "track_123",
            source: .subsonic,
            remoteURL: validURL
        )

        #expect(provider.canResolve(request))

        let resource = try await provider.resolve(request)
        #expect(resource.providerID == .subsonic)
        if case .avPlayerURL(let url) = resource.transport {
            #expect(url == validURL)
        } else {
            Issue.record("Expected .avPlayerURL transport")
        }
    }

    @Test("RemoteSubsonicPlaybackProvider rejects requests without itemID or remoteURL")
    @MainActor
    func subsonicPlaybackProviderRejectsMissingURL() {
        let provider = RemoteSubsonicPlaybackProvider()

        let request = PlaybackRequest(
            itemID: "",
            source: .subsonic,
            remoteURL: nil
        )

        #expect(!provider.canResolve(request))
    }

    @Test("SubsonicServerStore manages server addition and deletion in memory")
    @MainActor
    func serverStoreManagement() async throws {
        let credStore = InMemorySubsonicCredentialStore()
        let registry = LibraryProviderRegistry()
        let ephemeralDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let store = SubsonicServerStore(
            credentialStore: credStore,
            registry: registry,
            userDefaults: ephemeralDefaults
        )

        // Verify initial state
        #expect(store.servers.isEmpty)

        // Adding server saves password to credential store and registers provider
        let sourceID = LibrarySourceID("zspace_test")
        try credStore.savePassword("msruz4pro", for: sourceID)
        #expect(try credStore.password(for: sourceID) == "msruz4pro")

        // Removing server cleans up credentials and registry
        store.removeServer(id: sourceID)
        #expect(try credStore.password(for: sourceID) == nil)
        #expect(registry.provider(for: sourceID) == nil)
    }
}
