//
//  MacSceneRoutingTests.swift
//  MSRUTests
//

#if os(macOS)

import Foundation
import Testing
import AppFoundation

@testable import MSRU


@MainActor
struct MacSceneRoutingTests {

    @Test
    func routingToExplicitSceneOnlyChangesThatScene() {

        let sceneA =
            SceneRestorationSnapshot(
                sceneID:
                    SceneID(),
                section:
                    .listenNow,
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
                    true
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


        let routedID =
            fixture.coordinator
                .route(
                    SceneRoutingRequest(
                        route:
                            .section(
                                .settings
                            ),
                        target:
                            .scene(
                                sceneA.sceneID
                            )
                    )
                )


        #expect(
            routedID
            ==
            sceneA.sceneID
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
            .settings
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
    }


    @Test
    func routingToNewCreatesNewSceneWithRoute() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let originalCount =
            fixture.factory
                .windows
                .count


        let newSceneID =
            fixture.coordinator
                .route(
                    SceneRoutingRequest(
                        route:
                            .section(
                                .browse
                            ),
                        target:
                            .new
                    )
                )


        let requiredID =
            try! #require(
                newSceneID
            )


        #expect(
            fixture.factory
                .windows
                .count
            ==
            originalCount
            + 1
        )


        #expect(
            fixture.factory
                .windows[
                    requiredID
                ]?
                .scene
                .navigation
                .section
            ==
            .browse
        )
    }


    @Test
    func activeOrNewRoutesToActiveScene() {

        let sceneA =
            SceneRestorationSnapshot(
                sceneID:
                    SceneID(),
                section:
                    .listenNow,
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
                    true
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


        fixture.factory
            .setActive(
                sceneB.sceneID
            )


        let routedID =
            fixture.coordinator
                .route(
                    SceneRoutingRequest(
                        route:
                            .section(
                                .radio
                            )
                    )
                )


        #expect(
            routedID
            ==
            sceneB.sceneID
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
            .radio
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
            .listenNow
        )
    }


    @Test
    func routingToMissingExplicitSceneFailsWithoutCreatingWindow() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let originalCount =
            fixture.factory
                .windows
                .count


        let result =
            fixture.coordinator
                .route(
                    SceneRoutingRequest(
                        route:
                            .section(
                                .settings
                            ),
                        target:
                            .scene(
                                SceneID()
                            )
                    )
                )


        #expect(
            result
            ==
            nil
        )


        #expect(
            fixture.factory
                .windows
                .count
            ==
            originalCount
        )
    }


    @Test
    func routedStateIsImmediatelyPersisted() {

        let fixture =
            makeFixture()


        fixture.coordinator
            .start()


        let sceneID =
            fixture.factory
                .windows
                .keys
                .first!


        fixture.coordinator
            .route(
                SceneRoutingRequest(
                    route:
                        .section(
                            .settings
                        ),
                    target:
                        .scene(
                            sceneID
                        )
                )
            )


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
    }


    // MARK: - Fixture

    private func makeFixture(
        snapshots:
            [SceneRestorationSnapshot] = []
    ) -> RoutingFixture {

        let application =
            makeRoutingApplication()


        let store =
            RoutingRestorationStore(
                snapshots:
                    snapshots
            )


        let factory =
            RoutingWindowFactory()


        let coordinator =
            MacSceneCoordinator(
                application:
                    application,
                restorationStore:
                    store,
                windowFactory:
                    factory
            )


        return RoutingFixture(
            store:
                store,
            factory:
                factory,
            coordinator:
                coordinator
        )
    }
}


// MARK: - Fixture

@MainActor
private struct RoutingFixture {

    let store:
        RoutingRestorationStore


    let factory:
        RoutingWindowFactory


    let coordinator:
        MacSceneCoordinator
}


// MARK: - Store Double

@MainActor
private final class RoutingRestorationStore:
    SceneRestorationStore {

    private var snapshots:
        [
            SceneID:
                SceneRestorationSnapshot
        ]


    init(
        snapshots:
            [SceneRestorationSnapshot]
    ) {

        self.snapshots =
            Dictionary(
                uniqueKeysWithValues:
                    snapshots.map {
                        (
                            $0.sceneID,
                            $0
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
private final class RoutingWindowFactory:
    MacSceneWindowFactory {

    private(set) var windows:
        [
            SceneID:
                RoutingWindow
        ] = [:]


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

        let window =
            RoutingWindow(
                scene:
                    scene,
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


    func setActive(
        _ sceneID:
            SceneID
    ) {

        for window
        in windows.values {

            window.active =
                window.sceneID
                ==
                sceneID
        }
    }
}


// MARK: - Window Double

@MainActor
private final class RoutingWindow:
    MacSceneWindow {

    let scene:
        SceneModel


    private let onSceneClosed:
        @MainActor (
            SceneID
        ) -> Void


    var active =
        false


    init(
        scene:
            SceneModel,
        onSceneClosed:
            @escaping @MainActor (
                SceneID
            ) -> Void
    ) {

        self.scene =
            scene


        self.onSceneClosed =
            onSceneClosed
    }


    var sceneID:
        SceneID {

        scene.id
    }


    var isActive:
        Bool {

        active
    }


    func activate() {

        /*
         Tests that require precise active Window
         use factory.setActive(_:).
         */
    }


    func restorationSnapshot()
        -> SceneRestorationSnapshot {

        scene
            .restorationSnapshot()
    }
}


// MARK: - Application

@MainActor
private func makeRoutingApplication()
    -> ApplicationModel {

    let library =
        LibraryStore(
            repository:
                RoutingLibraryRepository()
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
private final class RoutingLibraryRepository:
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

#endif
