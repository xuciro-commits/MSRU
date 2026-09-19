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


    @Test
    func mixedRecordsRestoreIndependentlyAndOpaqueRecordsSurviveWrites() throws {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let key = "MSRU.SceneRestoration.Snapshots.v1"
        let valid = SceneRestorationSnapshot(sceneID: SceneID(), section: .browse, isQueuePresented: true)
        let validRecord = try JSONSerialization.jsonObject(with: JSONEncoder().encode(valid))
        let unknown: [String: Any] = ["version": 99, "payload": ["future": true]]
        let invalid: [String: Any] = ["version": 1, "sceneID": "broken"]
        fixture.defaults.set(try JSONSerialization.data(withJSONObject: [validRecord, unknown, invalid, NSNull()]), forKey: key)
        #expect(fixture.store.loadSnapshots() == [valid])
        var updated = valid
        updated.section = .library
        fixture.store.save(updated)
        #expect(fixture.store.loadSnapshots() == [updated])
        fixture.store.remove(sceneID: valid.sceneID)
        #expect(fixture.store.loadSnapshots().isEmpty)
        let remainingData = try #require(fixture.defaults.data(forKey: key))
        let remaining = try #require(JSONSerialization.jsonObject(with: remainingData) as? [Any])
        #expect(remaining.count == 3)
        #expect((remaining[0] as? NSDictionary) == (unknown as NSDictionary))
        #expect((remaining[1] as? NSDictionary) == (invalid as NSDictionary))
        #expect(remaining[2] is NSNull)
    }

    @Test
    func corruptDocumentIsPreservedBeforeReplacement() throws {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let key = "MSRU.SceneRestoration.Snapshots.v1"
        let original = Data("not valid JSON".utf8)
        fixture.defaults.set(original, forKey: key)
        #expect(fixture.store.loadSnapshots().isEmpty)
        #expect(fixture.defaults.data(forKey: key) == original)
        let snapshot = SceneRestorationSnapshot(sceneID: SceneID(), section: .browse, isQueuePresented: false)
        fixture.store.save(snapshot)
        #expect(fixture.store.loadSnapshots() == [snapshot])
        #expect(fixture.defaults.array(forKey: key + ".quarantine") as? [Data] == [original])
        fixture.store.save(snapshot)
        #expect(fixture.defaults.array(forKey: key + ".quarantine") as? [Data] == [original])
    }

    @Test
    func duplicateSupportedRecordsResolveToLatestAndSaveConverges() throws {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let key = "MSRU.SceneRestoration.Snapshots.v1"
        let original = SceneRestorationSnapshot(sceneID: SceneID(), section: .browse, isQueuePresented: false)
        var updated = original
        updated.section = .library
        fixture.defaults.set(try JSONEncoder().encode([original, updated]), forKey: key)
        #expect(fixture.store.loadSnapshots() == [updated])
        fixture.store.save(original)
        let stored = try JSONDecoder().decode([SceneRestorationSnapshot].self, from: #require(fixture.defaults.data(forKey: key)))
        #expect(stored == [original])
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
