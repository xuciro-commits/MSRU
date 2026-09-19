import Foundation
import Testing
@testable import MSRU

@MainActor
private final class SuspendedLocalRepository: LocalLibraryRepository {
    var tracks: [LocalTrack] = []
    var started: (() -> Void)?
    var release: CheckedContinuation<Void, Never>?
    var suspendLoad = false
    var suspendImport = false
    var imports = 0

    func loadTracks() async throws -> [LocalTrack] {
        let snapshot = tracks
        if suspendLoad {
            suspendLoad = false
            await withCheckedContinuation { release = $0; started?() }
        }
        return snapshot
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        imports += 1
        if suspendImport {
            suspendImport = false
            await withCheckedContinuation { release = $0; started?() }
        }
        let track = LocalTrack(fileURL: url, title: url.lastPathComponent, artist: "Fixture",
                               album: nil, duration: 1, artworkData: nil)
        tracks.append(track)
        return track
    }
}

@MainActor
struct LocalLibraryOrderingTests {
    @Test
    func suspendedScanCannotOverwriteLaterImport() async {
        let repository = SuspendedLocalRepository()
        repository.suspendLoad = true
        let store = LocalLibraryStore(repository: repository)
        var loading: Task<Void, Never>?
        await withCheckedContinuation { started in
            repository.started = { started.resume() }
            loading = Task { await store.loadIfNeeded() }
        }
        var importing: Task<Void, Never>?
        await withCheckedContinuation { queued in
            importing = Task { @MainActor in
                queued.resume()
                await store.importFiles([URL(fileURLWithPath: "/fixture/new.wav")])
            }
        }
        #expect(repository.imports == 0)
        repository.release?.resume()
        repository.release = nil
        await loading?.value
        await importing?.value
        #expect(store.tracks.map(\.title) == ["new.wav"])
        #expect(store.tracks == repository.tracks)
    }

    @Test
    func secondImportIsQueuedInsteadOfSilentlyDiscarded() async {
        let repository = SuspendedLocalRepository()
        repository.suspendImport = true
        let store = LocalLibraryStore(repository: repository)
        var first: Task<Void, Never>?
        await withCheckedContinuation { started in
            repository.started = { started.resume() }
            first = Task { await store.importFiles([URL(fileURLWithPath: "/fixture/first.wav")]) }
        }
        var second: Task<Void, Never>?
        await withCheckedContinuation { queued in
            second = Task { @MainActor in
                queued.resume()
                await store.importFiles([URL(fileURLWithPath: "/fixture/second.wav")])
            }
        }
        #expect(store.isImporting)
        #expect(repository.imports == 1)
        repository.release?.resume()
        repository.release = nil
        await first?.value
        await second?.value
        #expect(repository.imports == 2)
        #expect(store.tracks.count == 2)
        #expect(!store.isImporting)
    }
}
