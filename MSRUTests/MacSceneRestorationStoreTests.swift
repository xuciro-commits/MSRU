//
//  MacSceneRestorationStoreTests.swift
//  MSRUTests
//

#if os(macOS)

import Foundation
import Testing
import AppFoundation

@testable import MSRU


@MainActor
struct MacSceneRestorationStoreTests {

    @Test
    func storeSavesAndLoadsMultipleScenes() {

        let fixture =
            makeFixture()


        defer {

            fixture.defaults
                .removePersistentDomain(
                    forName:
                        fixture.suiteName
                )
        }


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


        fixture.store.save(
            sceneA
        )


        fixture.store.save(
            sceneB
        )


        let loaded =
            fixture.store
                .loadSnapshots()


        #expect(
            loaded.count
            ==
            2
        )


        #expect(
            loaded.contains(
                sceneA
            )
        )


        #expect(
            loaded.contains(
                sceneB
            )
        )
    }


    @Test
    func storeReplacesExistingSceneSnapshot() {

        let fixture =
            makeFixture()


        defer {

            fixture.defaults
                .removePersistentDomain(
                    forName:
                        fixture.suiteName
                )
        }


        let sceneID =
            SceneID()


        fixture.store.save(
            SceneRestorationSnapshot(
                sceneID:
                    sceneID,
                section:
                    .listenNow,
                isQueuePresented:
                    true
            )
        )


        fixture.store.save(
            SceneRestorationSnapshot(
                sceneID:
                    sceneID,
                section:
                    .settings,
                isQueuePresented:
                    false
            )
        )


        let loaded =
            fixture.store
                .loadSnapshots()


        #expect(
            loaded.count
            ==
            1
        )


        #expect(
            loaded.first?
                .section
            ==
            .settings
        )


        #expect(
            loaded.first?
                .isQueuePresented
            ==
            false
        )
    }


    @Test
    func storeRemovesClosedScene() {

        let fixture =
            makeFixture()


        defer {

            fixture.defaults
                .removePersistentDomain(
                    forName:
                        fixture.suiteName
                )
        }


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
                    true
            )


        fixture.store.save(
            sceneA
        )


        fixture.store.save(
            sceneB
        )


        fixture.store.remove(
            sceneID:
                sceneA.sceneID
        )


        #expect(
            fixture.store
                .loadSnapshots()
            ==
            [
                sceneB
            ]
        )
    }


    @Test
    func corruptPersistenceFailsSoftly() {

        let fixture =
            makeFixture()


        defer {

            fixture.defaults
                .removePersistentDomain(
                    forName:
                        fixture.suiteName
                )
        }


        fixture.defaults.set(
            Data(
                "corrupt"
                    .utf8
            ),
            forKey:
                "MSRU.SceneRestoration.Snapshots.v1"
        )


        #expect(
            fixture.store
                .loadSnapshots()
                .isEmpty
        )
    }


    // MARK: - Fixture

    private func makeFixture()
        -> (
            suiteName: String,
            defaults: UserDefaults,
            store: MacSceneRestorationStore
        ) {

        let suiteName =
            "MSRU.Tests.SceneRestoration."
            +
            UUID()
                .uuidString


        let defaults =
            UserDefaults(
                suiteName:
                    suiteName
            )!


        return (
            suiteName,
            defaults,
            MacSceneRestorationStore(
                defaults:
                    defaults
            )
        )
    }
}

#endif
