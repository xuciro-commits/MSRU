//
//  SceneTests.swift
//  MSRUTests
//
//  Canonical tests for Scene Navigation, URL routing codecs, and restoration store.
//

import Foundation
import Testing
import AppFoundation
import MusicDomain
@testable import MSRU

@Suite("Scene Routing & Navigation Invariants")
struct SceneTests {

    // MARK: - SceneRouteURLCodec

    @Test("SceneRouteURLCodec round-trips all SceneSection cases")
    func routeCodecRoundTrip() {
        let codec = SceneRouteURLCodec(scheme: "msru")

        for section in SceneSection.allCases {
            let route = SceneRoute.section(section)
            guard let url = codec.encode(route) else {
                Issue.record("Failed to encode route: \(route)")
                continue
            }

            #expect(url.scheme == "msru")
            #expect(url.host == "section")
            #expect(url.path == "/\(section.rawValue)")

            let decoded = codec.decode(url)
            #expect(decoded == route)
            #expect(decoded?.rootSection == section)
        }
    }

    @Test("SceneRouteURLCodec rejects invalid schemes, hosts, and paths gracefully")
    func routeCodecInvalidURLs() {
        let codec = SceneRouteURLCodec(scheme: "msru")

        // Wrong scheme
        let wrongSchemeURL = URL(string: "https://section/library")!
        #expect(codec.decode(wrongSchemeURL) == nil)

        // Wrong host
        let wrongHostURL = URL(string: "msru://window/library")!
        #expect(codec.decode(wrongHostURL) == nil)

        // Extra path components
        let deepPathURL = URL(string: "msru://section/library/nested")!
        #expect(codec.decode(deepPathURL) == nil)

        // Unknown section identifier
        let unknownSectionURL = URL(string: "msru://section/nonexistent_section_42")!
        #expect(codec.decode(unknownSectionURL) == nil)

        // Empty path
        let emptyPathURL = URL(string: "msru://section")!
        #expect(codec.decode(emptyPathURL) == nil)
    }

    // MARK: - SceneNavigation

    @MainActor
    @Test("SceneNavigation state transitions and reset")
    func sceneNavigationTransitions() {
        let navigation = SceneNavigation()
        #expect(navigation.section == .listenNow)
        #expect(navigation.route == .section(.listenNow))

        navigation.select(.library)
        #expect(navigation.section == .library)
        #expect(navigation.route == .section(.library))

        navigation.navigate(to: .section(.settings))
        #expect(navigation.section == .settings)

        navigation.reset()
        #expect(navigation.section == .listenNow)
    }

    // MARK: - MacSceneRestorationStore

    #if os(macOS)
    @MainActor
    @Test("MacSceneRestorationStore saves, updates, and removes snapshots deterministically")
    func sceneRestorationStoreOperations() throws {
        let suiteName = "test-scene-restoration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacSceneRestorationStore(defaults: defaults)

        // Initially empty
        #expect(store.loadSnapshots().isEmpty)

        let scene1 = SceneID()
        let snapshot1 = SceneRestorationSnapshot(
            sceneID: scene1,
            section: .albums,
            isQueuePresented: true
        )
        store.save(snapshot1)

        let loaded1 = store.loadSnapshots()
        #expect(loaded1.count == 1)
        #expect(loaded1.first?.sceneID == scene1)
        #expect(loaded1.first?.section == .albums)
        #expect(loaded1.first?.isQueuePresented == true)

        // Update existing scene snapshot
        let snapshot1Updated = SceneRestorationSnapshot(
            sceneID: scene1,
            section: .playlists,
            isQueuePresented: false
        )
        store.save(snapshot1Updated)

        let loadedUpdated = store.loadSnapshots()
        #expect(loadedUpdated.count == 1)
        #expect(loadedUpdated.first?.section == .playlists)
        #expect(loadedUpdated.first?.isQueuePresented == false)

        // Add second scene snapshot
        let scene2 = SceneID()
        let snapshot2 = SceneRestorationSnapshot(
            sceneID: scene2,
            section: .radio,
            isQueuePresented: false
        )
        store.save(snapshot2)
        #expect(store.loadSnapshots().count == 2)

        // Remove first scene
        store.remove(sceneID: scene1)
        let remaining = store.loadSnapshots()
        #expect(remaining.count == 1)
        #expect(remaining.first?.sceneID == scene2)
    }

    @MainActor
    @Test("MacSceneRestorationStore ignores unsupported future version snapshots")
    func sceneRestorationStoreUnsupportedVersions() throws {
        let suiteName = "test-scene-unsupported-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacSceneRestorationStore(defaults: defaults)

        let unsupportedSnapshot = SceneRestorationSnapshot(
            version: 999,
            sceneID: SceneID(),
            section: .library,
            isQueuePresented: false
        )
        #expect(unsupportedSnapshot.isSupported == false)

        store.save(unsupportedSnapshot)
        #expect(store.loadSnapshots().isEmpty)
    }
    #endif
}
