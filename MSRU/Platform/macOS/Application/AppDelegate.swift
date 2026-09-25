//
//  AppDelegate.swift
//  MSRU
//

#if os(macOS)

import MusicLibrary
import MusicPlayback
import AppKit
import AppFoundation
import CoreSpotlight

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Platform Scene Runtime
    private let sceneCoordinator: MacSceneCoordinator

    // MARK: - Command Runtime
    private let commandRuntime: MultiSceneApplicationCommandRuntime

    // MARK: - Lifecycle Runtime
    private let lifecycleRuntime: ApplicationLifecycleRuntime

    // MARK: - External Command Source
    private let externalURLSource = SceneRouteURLCommandSource(scheme: "msru")

    // MARK: - Init
    override convenience init() {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["MSRU_UI_TEST_SUITE"],
           suite.hasPrefix("MSRU.UITests."), let defaults = UserDefaults(suiteName: suite) {
            self.init(sceneCoordinator: MacSceneCoordinator(
                application: MSRUPreviewData.makeApplication(),
                restorationStore: MacSceneRestorationStore(defaults: defaults),
                windowFactory: MainSceneWindowFactory(splitAutosaveName: nil)))
            return
        }
        #endif
        self.init(sceneCoordinator: MacSceneCoordinator(
            application: ApplicationModel(), restorationStore: MacSceneRestorationStore()))
    }

    init(sceneCoordinator: MacSceneCoordinator) {
        let commandRuntime = MultiSceneApplicationCommandRuntime(runtime: sceneCoordinator)
        let lifecycleRuntime = ApplicationLifecycleRuntime(commandRuntime: commandRuntime)

        self.sceneCoordinator = sceneCoordinator
        self.commandRuntime = commandRuntime
        self.lifecycleRuntime = lifecycleRuntime

        super.init()
    }

    // MARK: - Playback & Application Access
    var application: ApplicationModel {
        sceneCoordinator.application
    }

    var playback: PlaybackController {
        sceneCoordinator.application.playback
    }

    // MARK: - Window Activation
    func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        sceneCoordinator.reopen()
    }

    // MARK: - Command Entry
    @discardableResult
    func send(_ command: ApplicationCommand) -> ApplicationCommandResult {
        commandRuntime.send(command)
    }

    // MARK: - Launch
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningForPreviews else { return }

        lifecycleRuntime.beginBootstrap()
        sceneCoordinator.start()
        lifecycleRuntime.markReady()
    }

    // MARK: - External URL
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !isRunningForPreviews else { return }
        let commands = urls.compactMap { externalURLSource.command(from: $0) }
        commandRuntime.send(commands)
    }

    func application(
        _ application: NSApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              SpotlightMusicID(rawValue: identifier) != nil else { return false }
        sceneCoordinator.openSpotlightItem(identifier)
        return true
    }

    // MARK: - Reopen
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isRunningForPreviews else { return false }
        guard !flag else { return true }
        sceneCoordinator.reopen()
        return true
    }

    // MARK: - Termination
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isRunningForPreviews else { return .terminateNow }
        sceneCoordinator.prepareForTermination()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !isRunningForPreviews else { return }
        sceneCoordinator.prepareForTermination()
        lifecycleRuntime.terminate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        guard !isRunningForPreviews else { return false }
        return sceneCoordinator.terminatesAfterLastWindowClosed
    }

    // MARK: - Preview
    private var isRunningForPreviews: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || env["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }
}

#endif
