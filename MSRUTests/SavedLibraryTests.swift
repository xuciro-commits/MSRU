import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
private final class SavedLibraryRepositoryDouble: LibraryRepository {
    var tracks: [LibraryTrack] = []
    var failLoad = false
    var failSave = false
    var saves = 0
    var saveStarted: (() -> Void)?
    var releaseSave: CheckedContinuation<Void, Never>?
    var suspendNextSave = false

    func loadTracks() async throws -> [LibraryTrack] {
        if failLoad { throw CocoaError(.fileReadCorruptFile) }
        return tracks
    }
    func saveTracks(_ tracks: [LibraryTrack]) async throws {
        saves += 1
        if suspendNextSave {
            suspendNextSave = false
            await withCheckedContinuation { continuation in
                releaseSave = continuation
                saveStarted?()
            }
        }
        if failSave { throw CocoaError(.fileWriteNoPermission) }
        self.tracks = tracks
    }
}

@MainActor
struct SavedLibraryTests {
    @Test
    func failedWritesLeaveCommittedStateUnchanged() async {
        let repository = SavedLibraryRepositoryDouble()
        let existing = LibraryTrack(local: MSRUPreviewData.localTracks[0])
        repository.tracks = [existing]
        repository.failSave = true
        let store = LibraryStore(repository: repository)
        let added = await store.add(local: MSRUPreviewData.localTracks[1])
        #expect(!added)
        #expect(store.tracks == [existing])
        #expect(repository.tracks == [existing])
        let removed = await store.remove(id: existing.id)
        #expect(!removed)
        #expect(store.tracks == [existing])
        #expect(store.errorMessage != nil)
        #expect(!store.isSaving)
    }

    @Test
    func failedInitialLoadCannotOverwriteExistingPersistence() async {
        let repository = SavedLibraryRepositoryDouble()
        repository.failLoad = true
        let store = LibraryStore(repository: repository)
        let added = await store.add(local: MSRUPreviewData.localTracks[0])
        #expect(!added)
        #expect(repository.saves == 0)
        #expect(!store.hasLoaded)
    }

    @Test
    func overlappingAddsWaitForCommitAndRetainBothTracks() async {
        let repository = SavedLibraryRepositoryDouble()
        repository.suspendNextSave = true
        let store = LibraryStore(repository: repository)
        var first: Task<Bool, Never>?
        await withCheckedContinuation { started in
            repository.saveStarted = { started.resume() }
            first = Task { await store.add(local: MSRUPreviewData.localTracks[0]) }
        }
        #expect(store.tracks.isEmpty)
        #expect(store.isSaving)
        var second: Task<Bool, Never>?
        await withCheckedContinuation { entered in
            second = Task { @MainActor in
                entered.resume()
                return await store.add(local: MSRUPreviewData.localTracks[1])
            }
        }
        #expect(repository.saves == 1)
        repository.releaseSave?.resume()
        repository.releaseSave = nil
        let firstAdded = await first?.value
        let secondAdded = await second?.value
        #expect(firstAdded == true)
        #expect(secondAdded == true)
        #expect(store.tracks.count == 2)
        #expect(repository.tracks == store.tracks)
        #expect(!store.isSaving)
    }

    @Test
    func savedTrackSurvivesRepositoryRecreationAndStartsLibraryPlayback() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Library.json")
        let original = LibraryStore(repository: JSONLibraryRepository(fileURL: url))
        let added = await original.add(local: MSRUPreviewData.localTracks[0])
        #expect(added)
        let reopened = LibraryStore(repository: JSONLibraryRepository(fileURL: url))
        await reopened.load()
        let track = try #require(reopened.tracks.first)
        #expect(track.id == original.tracks.first?.id)
        let playback = MSRUPreviewData.makePlaybackController()
        defer { playback.stop() }
        var dependencies = DependencyValues.test
        dependencies.library = reopened
        dependencies.playback = playback
        let feature = withDependencies(dependencies) { FeatureHost<LibraryFeature>(service: .init()) }
        feature.send(.playRequested(id: track.id))
        #expect(playback.currentItem?.title == track.title)
        #expect(playback.currentItem?.playbackRequest.localFileURL == MSRUPreviewData.localTracks[0].fileURL)
    }

    @Test
    func unsupportedSavedSourceIsNotMisrepresentedAsPlayable() {
        let track = LibraryTrack(title: "Future", artist: "Artist", sources: [
            LibraryPlaybackSource(kind: .appleMusic, externalID: "123")
        ])
        #expect(PlaybackItem(library: track) == nil)
    }
}
