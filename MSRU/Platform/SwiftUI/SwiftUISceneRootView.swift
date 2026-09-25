#if os(iOS) || os(visionOS)

import MusicLibrary
import MusicPlayback
import Foundation
import SwiftUI
import AppFoundation
import AppFoundationUI
import CoreSpotlight

@MainActor
struct SwiftUISceneRootView: View {

    // MARK: - Application
    let application: ApplicationModel

    // MARK: - External Command Source
    private let externalURLSource = SceneRouteURLCommandSource(scheme: "msru")

    // MARK: - Command Runtime
    @State private var commandRuntime: SingleSceneApplicationCommandRuntime

    // MARK: - Lifecycle Runtime
    @State private var lifecycleRuntime: ApplicationLifecycleRuntime

    // MARK: - Platform Restoration
    @SceneStorage("MSRU.Scene.RestorationSnapshot")
    private var restorationJSON: String?

    // MARK: - Scene Runtime
    @State private var scene: SceneModel?
    @State private var shellSession: MSRUApplicationShellSession?
    @State private var pendingSpotlightIdentifier: String?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Init
    init(application: ApplicationModel) {
        self.application = application
        let commandRuntime = SingleSceneApplicationCommandRuntime()
        _commandRuntime = State(initialValue: commandRuntime)
        _lifecycleRuntime = State(initialValue: ApplicationLifecycleRuntime(commandRuntime: commandRuntime))
    }

    // MARK: - Body
    var body: some View {
        Group {
            if let scene {
                sceneContent(scene)
            } else {
                ProgressView()
            }
        }
        .applyLocaleOverride(application.languageSettings.resolvedLocale)
        .task {
            bootstrapIfNeeded()
        }
        .onOpenURL { url in
            handleExternalURL(url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  SpotlightMusicID(rawValue: identifier) != nil else { return }
            if let scene {
                Task { await SpotlightSelectionRouter.open(identifier: identifier, in: scene) }
            } else {
                pendingSpotlightIdentifier = identifier
            }
        }
    }

    // MARK: - Content
    private func sceneContent(_ scene: SceneModel) -> some View {
        Group {
            if let shellSession {
                if horizontalSizeClass == .compact {
                    CompactApplicationShell(
                        scene: scene,
                        shellSession: shellSession
                    )
                } else {
                    regularSplitShell(
                        scene: scene,
                        shellSession: shellSession
                    )
                }
            }
        }
        .onChange(of: scene.navigation.section) {
            persist(scene)
        }
        .onChange(of: scene.isQueuePresented) {
            persist(scene)
        }
    }

    private func regularSplitShell(
        scene: SceneModel,
        shellSession: MSRUApplicationShellSession
    ) -> some View {
        SwiftUIApplicationShell(
            shell: shellSession.resolve(),
            isContextPresented: Binding(get: { scene.isQueuePresented }, set: { scene.isQueuePresented = $0 })
        ) {
            SidebarPaneView(scene: scene)
        }
        .overlay {
            if scene.isNowPlayingPresented {
                NowPlayingCanvasView(
                    playback: scene.application.playback,
                    onClose: {
                        scene.setNowPlaying(presented: false)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: scene.isNowPlayingPresented)
    }

    // MARK: - External URL
    private func handleExternalURL(_ url: URL) {
        guard let command = externalURLSource.command(from: url) else { return }
        commandRuntime.send(command)
    }

    // MARK: - Bootstrap
    private func bootstrapIfNeeded() {
        guard lifecycleRuntime.phase == .initialized else { return }

        lifecycleRuntime.beginBootstrap()
        application.start()

        let resolvedScene = restoreOrCreateScene()
        scene = resolvedScene

        if let pendingSpotlightIdentifier {
            self.pendingSpotlightIdentifier = nil
            Task { await SpotlightSelectionRouter.open(identifier: pendingSpotlightIdentifier, in: resolvedScene) }
        }

        let session = MSRUApplicationShellSession(scene: resolvedScene)
        session.installShellActions { [weak resolvedScene] in
            resolvedScene?.isQueuePresented.toggle()
        }
        shellSession = session

        commandRuntime.attach(resolvedScene)
        lifecycleRuntime.markReady()
        persist(resolvedScene)
    }

    // MARK: - Restore / Create
    private func restoreOrCreateScene() -> SceneModel {
        if let restorationJSON,
           let data = restorationJSON.data(using: .utf8),
           let snapshot = try? JSONDecoder().decode(SceneRestorationSnapshot.self, from: data),
           let restoredScene = SceneModel(application: application, restoration: snapshot) {
            return restoredScene
        }
        return SceneModel(application: application)
    }

    // MARK: - Persist
    private func persist(_ scene: SceneModel) {
        guard let data = try? JSONEncoder().encode(scene.restorationSnapshot()),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        restorationJSON = json
    }
}

#Preview("iPad Application · Regular") {
    SwiftUISceneRootView(application: MSRUPreviewData.makeApplication())
}

#Preview("iPhone Application · Compact") {
    SwiftUISceneRootView(application: MSRUPreviewData.makeApplication())
        .environment(\.horizontalSizeClass, .compact)
}

#endif
