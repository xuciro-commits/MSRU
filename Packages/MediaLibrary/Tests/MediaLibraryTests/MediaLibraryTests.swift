//
//  MediaLibraryTests.swift
//  MediaLibraryTests
//

import Testing
import Foundation
@testable import MediaLibrary

@Suite("MediaLibrary Core Invariants")
struct MediaLibraryTests {

    @Test("MediaID ensures uniqueness across different sources even with identical rawValue")
    func mediaIDUniquenessAcrossSources() {
        let localID = MediaID(sourceID: .local, rawValue: "101")
        let homeSubsonicID = MediaID(sourceID: LibrarySourceID("subsonic.home"), rawValue: "101")
        let officeSubsonicID = MediaID(sourceID: LibrarySourceID("subsonic.office"), rawValue: "101")

        #expect(localID != homeSubsonicID)
        #expect(homeSubsonicID != officeSubsonicID)
        #expect(localID.description == "local::101")
        #expect(homeSubsonicID.description == "subsonic.home::101")
    }

    @Test("MediaID Codable roundtrip preserves sourceID and rawValue")
    func mediaIDCodableRoundtrip() throws {
        let original = MediaID(sourceID: LibrarySourceID("zspace_nas"), rawValue: "track_98765")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaID.self, from: data)

        #expect(decoded == original)
        #expect(decoded.sourceID.rawValue == "zspace_nas")
        #expect(decoded.rawValue == "track_98765")
    }

    @Test("LibraryCapabilities OptionSet behaves correctly with Codable and combinations")
    func libraryCapabilitiesBehavior() throws {
        var caps: LibraryCapabilities = [.browse, .streaming, .artwork]
        #expect(caps.contains(.browse))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.artwork))
        #expect(!caps.contains(.scrobbling))

        caps.insert(.openSubsonicExtensions)
        #expect(caps.contains(.openSubsonicExtensions))

        let data = try JSONEncoder().encode(caps)
        let decoded = try JSONDecoder().decode(LibraryCapabilities.self, from: data)
        #expect(decoded == caps)
    }

    @Test("LibraryProviderRegistry registers, retrieves, and removes providers")
    func registryManagement() {
        let registry = LibraryProviderRegistry()

        struct MockProvider: LibraryProvider {
            let sourceID: LibrarySourceID
            var source: LibrarySource {
                LibrarySource(id: sourceID, name: "Mock", kind: .local)
            }
            var capabilities: LibraryCapabilities { .localDefault }

            func fetchArtists() async throws -> [UnifiedArtist] { [] }
            func fetchAlbums(artistID: MediaID?) async throws -> [UnifiedAlbum] { [] }
            func fetchTracks(albumID: MediaID?) async throws -> [UnifiedTrack] { [] }
            func search(query: String) async throws -> UnifiedSearchResult { UnifiedSearchResult() }
        }

        let p1 = MockProvider(sourceID: LibrarySourceID("src1"))
        let p2 = MockProvider(sourceID: LibrarySourceID("src2"))

        registry.register(p1)
        registry.register(p2)

        #expect(registry.allProviders().count == 2)
        #expect(registry.provider(for: LibrarySourceID("src1")) != nil)
        #expect(registry.provider(for: LibrarySourceID("src3")) == nil)

        registry.remove(LibrarySourceID("src1"))
        #expect(registry.allProviders().count == 1)
        #expect(registry.provider(for: LibrarySourceID("src1")) == nil)
    }

    @Test("LibraryCoordinator aggregates data across multiple providers")
    @MainActor
    func coordinatorAggregation() async throws {
        struct SampleProvider: LibraryProvider {
            let sourceID: LibrarySourceID
            let albumsToReturn: [UnifiedAlbum]

            var source: LibrarySource {
                LibrarySource(id: sourceID, name: sourceID.rawValue, kind: .subsonic)
            }
            var capabilities: LibraryCapabilities { .fullSubsonic }

            func fetchArtists() async throws -> [UnifiedArtist] { [] }
            func fetchAlbums(artistID: MediaID?) async throws -> [UnifiedAlbum] { albumsToReturn }
            func fetchTracks(albumID: MediaID?) async throws -> [UnifiedTrack] { [] }
            func search(query: String) async throws -> UnifiedSearchResult { UnifiedSearchResult() }
        }

        let registry = LibraryProviderRegistry()
        let a1 = UnifiedAlbum(id: MediaID(sourceID: LibrarySourceID("srcA"), rawValue: "1"), title: "Album A", artist: "Artist 1")
        let a2 = UnifiedAlbum(id: MediaID(sourceID: LibrarySourceID("srcB"), rawValue: "2"), title: "Album B", artist: "Artist 2")

        registry.register(SampleProvider(sourceID: LibrarySourceID("srcA"), albumsToReturn: [a1]))
        registry.register(SampleProvider(sourceID: LibrarySourceID("srcB"), albumsToReturn: [a2]))

        let coordinator = LibraryCoordinator(registry: registry)
        let allAlbums = try await coordinator.albums(source: nil)
        #expect(allAlbums.count == 2)

        let srcAAlbums = try await coordinator.albums(source: LibrarySourceID("srcA"))
        #expect(srcAAlbums.count == 1)
        #expect(srcAAlbums.first?.title == "Album A")
    }
}
