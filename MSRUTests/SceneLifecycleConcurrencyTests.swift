//
//  SceneLifecycleConcurrencyTests.swift
//  MSRUTests
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

private actor AsyncSignal {
    private var signaled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if signaled { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func fire() {
        signaled = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}

@Suite
@MainActor
struct SceneLifecycleConcurrencyTests {

    // MARK: - Scene Close State & Mutations

    @Test
    func sceneCloseStopsFeatureHostsAndRejectsSubsequentMutations() {
        let app = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: app, section: .browse)

        #expect(!scene.isClosed)
        #expect(!scene.browse.isStopped)
        #expect(!scene.libraryFeature.isStopped)

        scene.close()

        #expect(scene.isClosed)
        #expect(scene.browse.isStopped)
        #expect(scene.libraryFeature.isStopped)

        // Idempotent close
        scene.close()
        #expect(scene.isClosed)

        // Mutations on closed scene are rejected
        scene.send(.navigate(.section(.library)))
        #expect(scene.navigation.section == .browse)

        scene.select(localTrack: MSRUPreviewData.localTracks[0])
        #expect(scene.selectedLocalTrack == nil)

        scene.select(libraryTrack: LibraryTrack(local: MSRUPreviewData.localTracks[0]))
        #expect(scene.selectedLibraryTrack == nil)

        let initialQueueState = scene.isQueuePresented
        scene.toggleQueue()
        #expect(scene.isQueuePresented == initialQueueState)

        // Actions on stopped feature host are dropped
        scene.browse.send(.queryChanged("after closed"))
        #expect(scene.browse.state.query != "after closed")
    }

    // MARK: - In-flight Task Invalidation on Scene Close

    @Test
    func closedSceneInFlightFeatureTaskCannotCommitResults() async {
        let searchStarted = AsyncSignal()
        let releaseSearch = AsyncSignal()

        let controlledSearchClient = OpenverseSearchClient { query in
            await searchStarted.fire()
            await releaseSearch.wait()
            return await MainActor.run { MSRUPreviewData.openverseResults }
        }

        let app = ApplicationModel(
            musicCatalog: MusicCatalogStore(),
            localLibrary: LocalLibraryStore(),
            library: LibraryStore(),
            musicLibrary: AppleMusicLibraryStore(),
            playback: PlaybackController(),
            providerManager: ProviderManagerStore(),
            openverseSearch: controlledSearchClient
        )

        let scene = SceneModel(application: app, section: .browse)

        // Trigger an in-flight search
        scene.browse.send(.searchRequested("mozart"))
        await searchStarted.wait()

        // Close the scene while search operation is still suspended
        scene.close()
        #expect(scene.isClosed)
        #expect(scene.browse.isStopped)

        // Release the suspended search operation
        await releaseSearch.fire()

        // Give the task time to finish processing
        for _ in 0..<10 {
            await Task.yield()
        }

        // Even though search succeeded in background, the stopped host refuses the commit
        #expect(scene.browse.state.results.isEmpty)
    }

    // MARK: - ApplicationModel Startup Lifecycle

    @Test
    func applicationModelStartupTaskLifecycle() async {
        let app = MSRUPreviewData.makeApplication()

        #expect(!app.hasStarted)
        #expect(app.startupTask == nil)
        #expect(!app.isTerminated)

        app.start()

        #expect(app.hasStarted)
        #expect(app.startupTask != nil)

        let initialTask = app.startupTask

        // Idempotent: repeated start does not spawn new task
        app.start()
        #expect(app.startupTask == initialTask)

        // Terminate cancels startup task
        app.terminate()
        #expect(app.isTerminated)
        #expect(app.startupTask?.isCancelled == true)

        // Calling start after terminate is a no-op
        app.start()
        #expect(app.startupTask == initialTask)
    }
}
