//
//  LocalLibraryCascadeDeletionTests.swift
//  MSRUTests
//

import Foundation
import Testing
@testable import MSRU

@MainActor
private final class MockDeletionRepository: LocalLibraryRepository {
    var tracks: [LocalTrack] = []
    var deletedIDs: Set<String> = []

    func loadTracks() async throws -> [LocalTrack] {
        tracks
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        nil
    }

    func saveTrackInPlace(_ track: LocalTrack) async throws {
        tracks.append(track)
    }

    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        deletedIDs.formUnion(ids)
        tracks.removeAll { ids.contains($0.id) }
    }
}

@MainActor
struct LocalLibraryCascadeDeletionTests {

    @Test
    func deleteSingleTrackRemovesFromStoreAndRepository() async {
        let repo = MockDeletionRepository()
        let t1 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/track1.flac"), title: "Track 1", artist: "Artist A", album: "Album 1", duration: 180)
        let t2 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/track2.flac"), title: "Track 2", artist: "Artist B", album: "Album 2", duration: 200)

        let store = LocalLibraryStore(repository: repo)
        await store.addTracks([t1, t2])
        #expect(store.tracks.count == 2)

        await store.deleteTracks(withIDs: [t1.id])
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.id == t2.id)
        #expect(repo.deletedIDs.contains(t1.id))
    }

    @Test
    func deleteAlbumCascadesToAllMatchingTracks() async {
        let repo = MockDeletionRepository()
        let t1 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/a1.flac"), title: "早", artist: "万能青年旅店", album: "冀西南林路行", duration: 180)
        let t2 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/a2.flac"), title: "泥河", artist: "万能青年旅店", album: "冀西南林路行", duration: 240)
        let t3 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/b1.flac"), title: "晴天", artist: "周杰伦", album: "叶惠美", duration: 269)

        let store = LocalLibraryStore(repository: repo)
        await store.addTracks([t1, t2, t3])
        #expect(store.tracks.count == 3)

        // Delete "冀西南林路行" album
        await store.deleteAlbum(title: "冀西南林路行", artist: "万能青年旅店")
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.title == "晴天")
        #expect(repo.deletedIDs.contains(t1.id))
        #expect(repo.deletedIDs.contains(t2.id))
    }

    @Test
    func deleteArtistCascadesToAllAlbumsAndTracks() async {
        let repo = MockDeletionRepository()
        let t1 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/j1.flac"), title: "以父之名", artist: "周杰伦", album: "叶惠美", duration: 342)
        let t2 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/j2.flac"), title: "晴天", artist: "周杰伦", album: "叶惠美", duration: 269)
        let t3 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/j3.flac"), title: "七里香", artist: "周杰伦", album: "七里香", duration: 299)
        let t4 = LocalTrack(fileURL: URL(fileURLWithPath: "/music/ad1.flac"), title: "Rolling in the Deep", artist: "Adele", album: "21", duration: 228)

        let store = LocalLibraryStore(repository: repo)
        await store.addTracks([t1, t2, t3, t4])
        #expect(store.tracks.count == 4)

        // Cascade delete artist "周杰伦"
        await store.deleteArtist(name: "周杰伦")
        #expect(store.tracks.count == 1)
        #expect(store.tracks.first?.artist == "Adele")
        #expect(repo.deletedIDs.contains(t1.id))
        #expect(repo.deletedIDs.contains(t2.id))
        #expect(repo.deletedIDs.contains(t3.id))
    }

    @Test
    func metadataProviderConfigStoreFunctionality() {
        let testDefaults = UserDefaults(suiteName: "TestMetadataProviderConfigStore")!
        testDefaults.removePersistentDomain(forName: "TestMetadataProviderConfigStore")
        let config = MetadataProviderConfigStore(userDefaults: testDefaults, defaultsKey: "test_key")
        #expect(config.isEnabled(.appleMusic))
        #expect(config.isEnabled(.musicBrainz))
        #expect(config.isEnabled(.coverArtArchive))
        #expect(config.isEnabled(.localEmbedded))

        // Toggle off
        config.setEnabled(.musicBrainz, isEnabled: false)
        #expect(!config.isEnabled(.musicBrainz))

        // Toggle back on
        config.setEnabled(.musicBrainz, isEnabled: true)
        #expect(config.isEnabled(.musicBrainz))

        // Move priority
        #expect(config.providerPriority.first == .appleMusic)
        config.move(from: IndexSet(integer: 0), to: 2)
        #expect(config.providerPriority.first != .appleMusic)
    }
}
