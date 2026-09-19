#if os(macOS)
import AppKit
import AppFoundation
import Foundation
import Testing
@testable import MSRU

@MainActor
private final class NativeWindowFactory: MacSceneWindowFactory {
    var scenes: [SceneID: SceneModel] = [:]
    var windows: [SceneID: MainSceneWindow] = [:]

    func makeWindow(scene: SceneModel,
                    onSnapshotChange: @escaping @MainActor (SceneRestorationSnapshot) -> Void,
                    onSceneClosed: @escaping @MainActor (SceneID) -> Void) -> any MacSceneWindow {
        let window = MainSceneWindow(scene: scene, splitAutosaveName: nil,
            onSnapshotChange: onSnapshotChange, onSceneClosed: onSceneClosed)
        scenes[scene.id] = scene
        windows[scene.id] = window
        return window
    }

    func nativeWindow(for id: SceneID) throws -> NSWindow {
        let delegate = try #require(windows[id])
        return try #require(NSApplication.shared.windows.first { $0.delegate === delegate })
    }

    func closeAll() {
        for native in NSApplication.shared.windows {
            if windows.values.contains(where: { native.delegate === $0 }) {
                native.close()
            }
        }
    }
}

@MainActor
struct NativeSceneLifecycleTests {
    @Test
    func nativeSearchTracksSceneChangesWithoutReplacingFocusedField() async throws {
        let suite = "MSRU.Tests.NativeSearch." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let factory = NativeWindowFactory()
        let coordinator = MacSceneCoordinator(application: MSRUPreviewData.makeApplication(),
            restorationStore: MacSceneRestorationStore(defaults: defaults), windowFactory: factory)
        defer { factory.closeAll() }
        let id = coordinator.openNewScene(route: .section(.browse))
        let scene = try #require(factory.scenes[id])
        let window = try factory.nativeWindow(for: id)
        let toolbar = try #require(window.toolbar)
        let search = try #require(toolbar.items.compactMap { $0 as? NSSearchToolbarItem }.first)
        search.beginSearchInteraction()
        #expect(window.makeFirstResponder(search.searchField))
        let responder = try #require(window.firstResponder)
        scene.browse.send(.queryChanged("Changed through scene"))

        // Wait for the observed value, not an assumed number of scheduler turns.
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while search.searchField.stringValue != "Changed through scene", ContinuousClock.now < deadline {
            await Task.yield()
        }
        #expect(search.searchField.stringValue == "Changed through scene")
        let currentSearch = try #require(toolbar.items.compactMap { $0 as? NSSearchToolbarItem }.first)
        #expect(currentSearch === search)
        #expect(window.firstResponder === responder)
        search.searchField.stringValue = "Typed through AppKit"
        let action = try #require(search.searchField.action)
        #expect(search.searchField.sendAction(action, to: search.searchField.target))
        #expect(scene.browse.state.query == "Typed through AppKit")
    }

    @Test
    func nativeCloseAndDelegateTerminationPreserveOnlyOpenScenes() throws {
        let suite = "MSRU.Tests.NativeLifecycle." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MacSceneRestorationStore(defaults: defaults)
        let factory = NativeWindowFactory()
        let coordinator = MacSceneCoordinator(application: MSRUPreviewData.makeApplication(),
            restorationStore: store, windowFactory: factory)
        let delegate = AppDelegate(sceneCoordinator: coordinator)
        defer { factory.closeAll() }
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let first = try #require(factory.scenes.keys.first)
        let second = coordinator.openNewScene(route: .section(.library))
        let firstWindow = try factory.nativeWindow(for: first)
        firstWindow.performClose(nil) // Real AppKit notification -> MainSceneWindow -> coordinator.
        #expect(factory.scenes[first]?.isClosed == true)
        #expect(store.loadSnapshots().map(\.sceneID) == [second])

        let reply = delegate.applicationShouldTerminate(NSApplication.shared)
        #expect(reply == .terminateNow)
        try factory.nativeWindow(for: second).performClose(nil)
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        let saved = try #require(store.loadSnapshots().first)
        #expect(saved.sceneID == second)
        #expect(saved.section == .library)
        #expect(factory.scenes[second]?.isClosed == true)

        let restoredFactory = NativeWindowFactory()
        let restoredCoordinator = MacSceneCoordinator(application: MSRUPreviewData.makeApplication(),
            restorationStore: MacSceneRestorationStore(defaults: defaults), windowFactory: restoredFactory)
        defer { restoredFactory.closeAll() }
        restoredCoordinator.start()
        #expect(restoredFactory.scenes.count == 1)
        #expect(restoredFactory.scenes[second]?.navigation.section == .library)
        #expect(try restoredFactory.nativeWindow(for: second).isVisible)
    }
}
#endif
