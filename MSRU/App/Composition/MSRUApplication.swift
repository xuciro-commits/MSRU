//
//  MSRUApplication.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

// MARK: - MSRU Application Definition

@MainActor
enum MSRUApplication {
    static let definition: ApplicationDefinition<SceneRoute, SceneModel> = {
        var builder = ApplicationDefinitionBuilder<SceneRoute, SceneModel>()

        // MARK: Feature Modules
        builder.add(ListenNowFeature.self)
        builder.add(BrowseFeature.self)
        builder.add(LibraryFeature.self)
        builder.add(AlbumsFeature.self)
        builder.add(ArtistsFeature.self)
        builder.add(PlaylistsFeature.self)
        builder.add(SourcesFeature.self)
        builder.add(RadioFeature.self)
        builder.add(AddMusicFeature.self)
        builder.add(SettingsFeature.self)

        let definition = builder.build()

        #if DEBUG
        let validation = definition.validate()
        assert(validation.isValid, validation.debugDescription)
        #endif

        return definition
    }()
}

// MARK: - Shell Presentation Context

@MainActor
struct MSRUApplicationShellContext {
    let scene: SceneModel
    let actions: Actions

    struct Actions {
        let toggleQueue: () -> Void
        let revealInFinder: (URL) -> Void
    }
}

// MARK: - MSRU Application Shell Presentation

@MainActor
enum MSRUApplicationShellPresentation {
    private enum ID {
        static let contextSurface = "msru.context"
        static let miniPlayer = "playback.mini-player"
        static let toggleQueue = "playback.toggle-queue"
    }

    static let contextSurface = ContextPresentation<MSRUApplicationShellContext>(
        id: ID.contextSurface,
        role: .inspector
    ) { context in
        MSRUContextPaneView(
            scene: context.scene,
            onRevealInFinder: context.actions.revealInFinder
        )
    }

    static let miniPlayer = AccessoryPresentation<MSRUApplicationShellContext>(
        id: ID.miniPlayer,
        scope: .application
    ) { context in
        MiniPlayerAccessoryView(
            playback: context.scene.application.playback,
            onToggleQueue: context.actions.toggleQueue,
            onToggleLyrics: {
                context.scene.toggleContextPane(.lyrics)
            },
            onExpandNowPlaying: {
                context.scene.setNowPlaying(presented: true)
            }
        )
    }

    static let toolbar = ToolbarPresentation<MSRUApplicationShellContext>(
        items: [
            .action(
                ToolbarActionPresentation(
                    id: ID.toggleQueue,
                    title: String(localized: "Inspector"),
                    systemImage: "sidebar.right",
                    perform: { context in
                        context.actions.toggleQueue()
                    }
                )
            )
        ]
    )

    static let definition = ApplicationShellPresentation<MSRUApplicationShellContext>(
        contexts: [contextSurface],
        accessories: [miniPlayer],
        toolbar: toolbar
    )
}

// MARK: - MSRU Application Shell Session

@MainActor
final class MSRUApplicationShellSession {
    let scene: SceneModel

    private let resolver: ApplicationShellResolver<SceneRoute, SceneModel, MSRUApplicationShellContext>
    private var toggleQueueAction: () -> Void = {}
    private var revealInFinderAction: (URL) -> Void = { _ in }

    init(scene: SceneModel) {
        self.scene = scene
        self.resolver = ApplicationShellResolver(
            definition: MSRUApplication.definition,
            shell: MSRUApplicationShellPresentation.definition
        )
    }

    func installShellActions(
        toggleQueue: @escaping () -> Void,
        revealInFinder: @escaping (URL) -> Void = { _ in }
    ) {
        toggleQueueAction = toggleQueue
        revealInFinderAction = revealInFinder
    }

    func resolve() -> ResolvedApplicationShell {
        resolver.resolve(
            route: scene.navigation.route,
            workspaceContext: scene,
            shellContext: makeShellContext()
        )
    }

    private func makeShellContext() -> MSRUApplicationShellContext {
        MSRUApplicationShellContext(
            scene: scene,
            actions: .init(
                toggleQueue: { [weak self] in
                    self?.toggleQueueAction()
                },
                revealInFinder: { [weak self] url in
                    self?.revealInFinderAction(url)
                }
            )
        )
    }
}
