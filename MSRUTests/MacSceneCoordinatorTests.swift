//
//  MacSceneCoordinatorTests.swift
//  MSRUTests
//

#if os(macOS)

import Foundation
import Testing
import AppFoundation

@testable import MSRU


// MARK: - Tests

@MainActor
struct MacSceneCoordinatorTests {

    @Test
    func startCreatesSceneWhenRestorationIsEmpty() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        #expect(
            fixture.factory
                .windows
                .count
            ==
            1
        )


        #expect(
            fixture.store
                .loadSnapshots()
                .count
            ==
            1
        )
    }


    @Test
    func startRestoresAllPersistedScenes() {

        let sceneA =
            SceneRestorationSnapshot(
                sceneID:
                    SceneID(),
                section:
                    .browse,
                isQueuePresented:
                    true
            )


        let sceneB =
            SceneRestorationSnapshot(
                sceneID:
                    SceneID(),
                section:
                    .library,
                isQueuePresented:
                    false
            )


        let fixture =
            makeFixture(
                snapshots: [
                    sceneA,
                    sceneB
                ]
            )


        fixture.coordinator
            .start()


        #expect(
            fixture.factory
                .windows
                .count
            ==
            2
        )


        #expect(
            fixture.factory
                .windows[
                    sceneA.sceneID
                ]?
                .scene
                .navigation
                .section
            ==
            .browse
        )


        #expect(
            fixture.factory
                .windows[
                    sceneB.sceneID
                ]?
                .scene
                .navigation
                .section
            ==
            .library
        )


        #expect(
            fixture.factory
                .windows[
                    sceneB.sceneID
                ]?
                .scene
                .isQueuePresented
            ==
            false
        )
    }


    @Test
    func openingNewSceneCreatesIndependentSceneRuntime() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let firstID =
            tryRequireOnlySceneID(
                fixture.factory
            )


        let secondID =
            fixture.coordinator
                .openNewScene()


        #expect(
            firstID
            !=
            secondID
        )


        let first =
            fixture.factory
                .windows[
                    firstID
                ]!


        let second =
            fixture.factory
                .windows[
                    secondID
                ]!


        #expect(
            first.scene
            !==
            second.scene
        )


        #expect(
            first.scene.browse
            !==
            second.scene.browse
        )


        #expect(
            first.scene.libraryFeature
            !==
            second.scene.libraryFeature
        )


        /*
         Application Scope 必须共享。
         */

        #expect(
            first.scene.application
            ===
            second.scene.application
        )


        #expect(
            first.scene.application.library
            ===
            second.scene.application.library
        )


        #expect(
            first.scene.application.playback
            ===
            second.scene.application.playback
        )
    }


    @Test
    func sceneNavigationRemainsIsolatedBetweenWindows() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let firstID =
            tryRequireOnlySceneID(
                fixture.factory
            )


        let secondID =
            fixture.coordinator
                .openNewScene()


        let first =
            fixture.factory
                .windows[
                    firstID
                ]!


        let second =
            fixture.factory
                .windows[
                    secondID
                ]!


        first.scene
            .navigation
            .select(
                .browse
            )


        second.scene
            .navigation
            .select(
                .library
            )


        #expect(
            first.scene
                .navigation
                .section
            ==
            .browse
        )


        #expect(
            second.scene
                .navigation
                .section
            ==
            .library
        )
    }


    @Test
    func activatingExistingSceneDoesNotCreateDuplicateWindow() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let sceneID =
            tryRequireOnlySceneID(
                fixture.factory
            )


        let window =
            fixture.factory
                .windows[
                    sceneID
                ]!


        let creationCount =
            fixture.factory
                .creationCount


        let activationCount =
            window
                .activationCount


        let activated =
            fixture.coordinator
                .activateScene(
                    sceneID
                )


        #expect(
            activated
        )


        #expect(
            fixture.factory
                .creationCount
            ==
            creationCount
        )


        #expect(
            window.activationCount
            ==
            activationCount
            + 1
        )
    }


    @Test
    func closingSceneRemovesRuntimeAndPersistence() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let sceneID =
            tryRequireOnlySceneID(
                fixture.factory
            )


        let window =
            fixture.factory
                .windows[
                    sceneID
                ]!


        window
            .simulateClose()


        #expect(
            fixture.store
                .loadSnapshots()
                .isEmpty
        )


        #expect(
            fixture.coordinator
                .activateScene(
                    sceneID
                )
            ==
            false
        )
    }


    @Test
    func saveScenesPersistsLatestSemanticState() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let sceneID =
            tryRequireOnlySceneID(
                fixture.factory
            )


        let window =
            fixture.factory
                .windows[
                    sceneID
                ]!


        window.scene
            .navigation
            .select(
                .settings
            )


        window.scene
            .isQueuePresented =
            false


        fixture.coordinator
            .saveScenes()


        let snapshot =
            fixture.store
                .loadSnapshots()
                .first {
                    $0.sceneID
                    ==
                    sceneID
                }


        #expect(
            snapshot?
                .section
            ==
            .settings
        )


        #expect(
            snapshot?
                .isQueuePresented
            ==
            false
        )
    }


    @Test
    func reopenCreatesFreshSceneAfterLastSceneWasClosed() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let oldSceneID =
            tryRequireOnlySceneID(
                fixture.factory
            )


        fixture.factory
            .windows[
                oldSceneID
            ]?
            .simulateClose()


        fixture.coordinator
            .reopen()


        #expect(
            fixture.factory
                .creationCount
            ==
            2
        )


        let newIDs =
            fixture.factory
                .windows
                .keys
                .filter {
                    $0
                    !=
                    oldSceneID
                }


        #expect(
            newIDs.count
            ==
            1
        )
    }


    @Test
    func closedWindowCannotRecreateRestorationOrNavigate() {
        let fixture = makeFixture()
        fixture.coordinator.start()
        let first = fixture.factory.windows.values.first!
        _ = fixture.coordinator.openNewScene()
        first.simulateClose()
        #expect(first.scene.isClosed)
        let oldRoute = first.scene.navigation.section
        first.scene.send(.navigate(.section(.settings)))
        #expect(first.scene.navigation.section == oldRoute)
        first.publishSnapshot()
        first.simulateClose()
        let snapshots = fixture.store.loadSnapshots()
        #expect(snapshots.count == 1)
        #expect(!snapshots.contains { $0.sceneID == first.sceneID })
    }

    // MARK: - Fixture

    private func makeFixture(
        snapshots:
            [SceneRestorationSnapshot] = []
    ) -> CoordinatorFixture {

        let application =
            makeCoordinatorTestApplication()


        let store =
            CoordinatorTestRestorationStore(
                snapshots:
                    snapshots
            )


        let factory =
            CoordinatorTestWindowFactory()


        let coordinator =
            MacSceneCoordinator(
                application:
                    application,
                restorationStore:
                    store,
                windowFactory:
                    factory
            )


        return CoordinatorFixture(
            application:
                application,
            store:
                store,
            factory:
                factory,
            coordinator:
                coordinator
        )
    }


    private func tryRequireOnlySceneID(
        _ factory:
            CoordinatorTestWindowFactory
    ) -> SceneID {

        precondition(
            factory.windows.count
            ==
            1
        )


        return
            factory
                .windows
                .keys
                .first!
    }
}


// MARK: - Fixture

@MainActor
private struct CoordinatorFixture {

    let application:
        ApplicationModel

    let store:
        CoordinatorTestRestorationStore

    let factory:
        CoordinatorTestWindowFactory

    let coordinator:
        MacSceneCoordinator
}


// MARK: - Restoration Store Double

@MainActor
private final class CoordinatorTestRestorationStore:
    SceneRestorationStore {

    private var snapshots:
        [
            SceneID:
                SceneRestorationSnapshot
        ]


    init(
        snapshots:
            [SceneRestorationSnapshot] = []
    ) {

        self.snapshots =
            Dictionary(
                uniqueKeysWithValues:
                    snapshots.map {
                        snapshot in

                        (
                            snapshot.sceneID,
                            snapshot
                        )
                    }
            )
    }


    func loadSnapshots()
        -> [SceneRestorationSnapshot] {

        Array(
            snapshots.values
        )
    }


    func save(
        _ snapshot:
            SceneRestorationSnapshot
    ) {

        snapshots[
            snapshot.sceneID
        ] =
            snapshot
    }


    func remove(
        sceneID:
            SceneID
    ) {

        snapshots[
            sceneID
        ] =
            nil
    }
}


// MARK: - Window Factory Double

@MainActor
private final class CoordinatorTestWindowFactory:
    MacSceneWindowFactory {

    private(set) var windows:
        [
            SceneID:
                CoordinatorTestWindow
        ] = [:]


    private(set) var creationCount =
        0


    func makeWindow(
        scene:
            SceneModel,
        onSnapshotChange:
            @escaping @MainActor (
                SceneRestorationSnapshot
            ) -> Void,
        onSceneClosed:
            @escaping @MainActor (
                SceneID
            ) -> Void
    ) -> any MacSceneWindow {

        creationCount +=
            1


        let window =
            CoordinatorTestWindow(
                scene:
                    scene,
                onSnapshotChange:
                    onSnapshotChange,
                onSceneClosed:
                    onSceneClosed
            )


        windows[
            scene.id
        ] =
            window


        return
            window
    }
}


// MARK: - Window Double

@MainActor
private final class CoordinatorTestWindow:
    MacSceneWindow {

    let scene:
        SceneModel


    private let onSnapshotChange:
        @MainActor (
            SceneRestorationSnapshot
        ) -> Void


    private let onSceneClosed:
        @MainActor (
            SceneID
        ) -> Void


    private(set) var activationCount =
        0


    init(
        scene:
            SceneModel,
        onSnapshotChange:
            @escaping @MainActor (
                SceneRestorationSnapshot
            ) -> Void,
        onSceneClosed:
            @escaping @MainActor (
                SceneID
            ) -> Void
    ) {

        self.scene =
            scene


        self.onSnapshotChange =
            onSnapshotChange


        self.onSceneClosed =
            onSceneClosed
    }


    var sceneID:
        SceneID {

        scene.id
    }


    func activate() {

        activationCount +=
            1
    }


    func restorationSnapshot()
        -> SceneRestorationSnapshot {

        scene
            .restorationSnapshot()
    }


    func publishSnapshot() {

        onSnapshotChange(
            restorationSnapshot()
        )
    }


    func simulateClose() {

        onSceneClosed(
            sceneID
        )
    }
}


// MARK: - Application Fixture

@MainActor
private func makeCoordinatorTestApplication()
    -> ApplicationModel {

    let library =
        LibraryStore(
            repository:
                CoordinatorTestLibraryRepository()
        )


    return ApplicationModel(
        musicCatalog:
            MusicCatalogStore(),
        localLibrary:
            LocalLibraryStore(),
        library:
            library,
        musicLibrary:
            AppleMusicLibraryStore(),
        playback:
            PlaybackController(),
        providerManager:
            ProviderManagerStore(),
        openverseSearch:
            .preview(
                results:
                    []
            )
    )
}


@MainActor
private final class CoordinatorTestLibraryRepository:
    LibraryRepository {

    private var tracks:
        [LibraryTrack] = []


    func loadTracks()
        async throws
        -> [LibraryTrack] {

        tracks
    }


    func saveTracks(
        _ tracks:
            [LibraryTrack]
    ) async throws {

        self.tracks =
            tracks
    }
}

struct MacSceneLifecyclePolicyTests {
    @Test
    func applicationTerminationPreservesRestoration() {
        let policy = MacSceneLifecyclePolicy()
        #expect(policy.restorationDisposition(isApplicationTerminating: true) == .preserve)
    }

    @Test
    func explicitSceneCloseRemovesRestoration() {
        let policy = MacSceneLifecyclePolicy()
        #expect(policy.restorationDisposition(isApplicationTerminating: false) == .remove)
    }

    @Test
    func lastWindowTerminationPolicyIsIndependentFromScenePersistence() {
        let policy = MacSceneLifecyclePolicy(terminatesAfterLastWindowClosed: true)
        #expect(policy.terminatesAfterLastWindowClosed)
        #expect(policy.restorationDisposition(isApplicationTerminating: false) == .remove)
    }
}

#endif
