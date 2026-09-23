//
//  SubsonicServerStoreTests.swift
//  MSRUTests
//

import Testing
import Foundation
@testable import MSRU
import SubsonicKit
import MusicDomain
import MusicLibrary
import MusicPlayback

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

    @Test("Legacy UserDefaults servers import once into sources with their username")
    @MainActor
    func legacyServersImportIntoSources() async throws {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let legacy = #"[{"id":{"rawValue":"subsonic_ab12cd34"},"name":"Home NAS","kind":"subsonic","capabilities":0,"state":"online","serverURL":"http://192.168.31.200:8025","username":"msru"}]"#
        defaults.set(Data(legacy.utf8), forKey: SourceRuntimeCoordinator.legacySubsonicServersKey)
        let db = try AppDatabase.makeEphemeral()
        let coordinator = SourceRuntimeCoordinator(
            db: db,
            credentialStore: InMemorySubsonicCredentialStore(),
            legacyDefaults: defaults
        )
        let store = SubsonicServerStore(coordinator: coordinator)
        await coordinator.loadRemoteSources()

        let server = try #require(store.servers.first)
        #expect(store.servers.count == 1)
        #expect(server.id == SourceID("src_subsonic_ab12cd34"))
        #expect(server.name == "Home NAS")
        #expect(server.username == "msru")
        #expect(server.status == .unknown)
        #expect(store.client(for: LibrarySourceID("subsonic_ab12cd34"))?.serverID == LibrarySourceID("subsonic_ab12cd34"))
        #expect(store.client(for: server.id) != nil)
        // The legacy value stays as a recovery path.
        #expect(defaults.data(forKey: SourceRuntimeCoordinator.legacySubsonicServersKey) != nil)

        // Removing the server must not resurrect it from the legacy list.
        await coordinator.removeSource(id: server.id)
        let reloaded = SourceRuntimeCoordinator(
            db: db,
            credentialStore: InMemorySubsonicCredentialStore(),
            legacyDefaults: defaults
        )
        await reloaded.loadRemoteSources()
        #expect(reloaded.subsonicSources.isEmpty)
    }

    @Test("Removing a server deletes its credential and client")
    @MainActor
    func removeServerCleansUp() async throws {
        let credentials = InMemorySubsonicCredentialStore()
        let db = try AppDatabase.makeEphemeral()
        let source = Source(
            id: SourceID("src_subsonic_zz99"),
            sourceType: .subsonic,
            uri: "http://192.168.31.200:8025",
            displayName: "Test",
            capabilities: [.supportsStreaming],
            username: "msru"
        )
        try await SourceRepository(db: db).insertOrUpdate(source)
        try credentials.savePassword("secret", for: LibrarySourceID("subsonic_zz99"))
        let coordinator = SourceRuntimeCoordinator(
            db: db,
            credentialStore: credentials,
            legacyDefaults: UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        )
        await coordinator.loadRemoteSources()
        #expect(coordinator.subsonicClient(for: source.id) != nil)

        await coordinator.removeSource(id: source.id)
        #expect(coordinator.subsonicClient(for: source.id) == nil)
        #expect(try credentials.password(for: LibrarySourceID("subsonic_zz99")) == nil)
        #expect(coordinator.subsonicSources.isEmpty)
    }

    @Test("Server keys and source IDs map to each other")
    func serverKeyMapping() {
        #expect(SourceID("src_subsonic_ab12").serverKey == "subsonic_ab12")
        #expect(SourceID(serverKeyOrSourceID: "subsonic_ab12") == SourceID("src_subsonic_ab12"))
        #expect(SourceID(serverKeyOrSourceID: "src_subsonic_ab12") == SourceID("src_subsonic_ab12"))
        #expect(SourceID.newSubsonic().rawValue.hasPrefix(SourceID.subsonicPrefix))
    }

    @Test("Legacy display names split into name and username")
    func legacyDisplayNameSplit() {
        #expect(Source.splitLegacySubsonicDisplayName("Home NAS (msru)") == ("Home NAS", "msru"))
        #expect(Source.splitLegacySubsonicDisplayName("极空间 (user) (admin)") == ("极空间 (user)", "admin"))
        #expect(Source.splitLegacySubsonicDisplayName("Plain") == ("Plain", nil))
        #expect(Source.splitLegacySubsonicDisplayName("() ") == ("() ", nil))
    }
}
