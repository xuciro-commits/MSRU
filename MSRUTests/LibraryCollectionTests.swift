//
//  LibraryCollectionTests.swift
//  MSRUTests
//

import Testing
import Foundation
@testable import MSRU

@Suite
@MainActor
struct LibraryCollectionTests {

    // MARK: - Test Fixtures

    private func makeTracks() -> [LibraryTrack] {
        [
            LibraryTrack(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "B Track",
                artist: "Artist Z",
                album: "Album M",
                duration: 240,
                dateAdded: Date(timeIntervalSince1970: 1000)
            ),
            LibraryTrack(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                title: "A Track",
                artist: "Artist A",
                album: "Album Z",
                duration: 180,
                dateAdded: Date(timeIntervalSince1970: 2000)
            ),
            LibraryTrack(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "C Track",
                artist: "Artist M",
                album: nil,
                duration: 300,
                dateAdded: Date(timeIntervalSince1970: 500)
            )
        ]
    }

    // MARK: - Sorting Tests

    @Test
    func sortByTitleAscendingAndDescending() {
        let tracks = makeTracks()

        let asc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .title,
            ascending: true
        )
        #expect(asc.map(\.title) == ["A Track", "B Track", "C Track"])

        let desc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .title,
            ascending: false
        )
        #expect(desc.map(\.title) == ["C Track", "B Track", "A Track"])
    }

    @Test
    func sortByArtist() {
        let tracks = makeTracks()

        let asc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .artist,
            ascending: true
        )
        #expect(asc.map(\.artist) == ["Artist A", "Artist M", "Artist Z"])
    }

    @Test
    func sortByDuration() {
        let tracks = makeTracks()

        let asc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .duration,
            ascending: true
        )
        #expect(asc.map(\.duration) == [180, 240, 300])

        let desc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .duration,
            ascending: false
        )
        #expect(desc.map(\.duration) == [300, 240, 180])
    }

    @Test
    func sortByDateAdded() {
        let tracks = makeTracks()

        let asc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .dateAdded,
            ascending: true
        )
        #expect(asc.map(\.title) == ["C Track", "B Track", "A Track"])

        let desc = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "",
            field: .dateAdded,
            ascending: false
        )
        #expect(desc.map(\.title) == ["A Track", "B Track", "C Track"])
    }

    // MARK: - Filter Tests

    @Test
    func filterByTitleOrArtistOrAlbum() {
        let tracks = makeTracks()

        let matchTitle = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "A Track",
            field: .title,
            ascending: true
        )
        #expect(matchTitle.count == 1)
        #expect(matchTitle.first?.title == "A Track")

        let matchArtist = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "Artist Z",
            field: .title,
            ascending: true
        )
        #expect(matchArtist.count == 1)
        #expect(matchArtist.first?.title == "B Track")

        let matchAlbum = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "Album M",
            field: .title,
            ascending: true
        )
        #expect(matchAlbum.count == 1)
        #expect(matchAlbum.first?.title == "B Track")

        let noMatch = LibraryCollectionSortFilter.filterAndSort(
            tracks: tracks,
            query: "Nonexistent",
            field: .title,
            ascending: true
        )
        #expect(noMatch.isEmpty)
    }

    // MARK: - Local Track Sort & Filter Tests

    @Test
    func localTrackSortAndFilter() {
        let localTracks = [
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/Zebra.mp3"),
                title: "Zebra",
                artist: "Beta",
                album: "First",
                duration: 200,
                artworkData: nil
            ),
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/Alpha.mp3"),
                title: "Alpha",
                artist: "Gamma",
                album: "Second",
                duration: 100,
                artworkData: nil
            )
        ]

        let sorted = LibraryCollectionSortFilter.filterAndSort(
            tracks: localTracks,
            query: "",
            field: .title,
            ascending: true
        )
        #expect(sorted.map(\.title) == ["Alpha", "Zebra"])

        let filtered = LibraryCollectionSortFilter.filterAndSort(
            tracks: localTracks,
            query: "Gamma",
            field: .title,
            ascending: true
        )
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Alpha")
    }

    // MARK: - SceneModel Selection Tests

    @Test
    @MainActor
    func selectLibraryTrackUpdatesInspectorStateAndEnsuresContextPresented() {
        let app = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: app, section: .library)
        let track = LibraryTrack(local: MSRUPreviewData.localTracks[0])

        scene.isQueuePresented = false
        scene.activeContextPane = .queue
        scene.selectedLocalTrack = MSRUPreviewData.localTracks[0]

        scene.select(libraryTrack: track)

        #expect(scene.selectedLibraryTrack?.id == track.id)
        #expect(scene.selectedLocalTrack == nil)
        #expect(scene.selectedMusicContent == nil)
        #expect(scene.activeContextPane == .inspector)
        #expect(scene.isQueuePresented == true)

        // Switching selection to local track clears library track
        scene.select(localTrack: MSRUPreviewData.localTracks[1])
        #expect(scene.selectedLibraryTrack == nil)
        #expect(scene.selectedLocalTrack?.id == MSRUPreviewData.localTracks[1].id)
    }
}
