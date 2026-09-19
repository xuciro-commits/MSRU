//
//  MSRUApplicationShellSession.swift
//  MSRU
//

import AppFoundationUI


// MARK: - MSRU Application Shell Session

/// Product-level runtime session for one Scene.
///
/// This is intentionally not a platform controller.
///
/// macOS, iPadOS, or another renderer can install their own
/// presentation actions while sharing the same semantic runtime.
@MainActor
final class MSRUApplicationShellSession {

    // MARK: - Scene

    let scene:
        SceneModel


    // MARK: - Runtime

    private let runtime:
        ApplicationShellRuntime<
            SceneRoute,
            SceneModel,
            MSRUApplicationShellContext
        >


    // MARK: - Platform Actions

    private var toggleQueueAction:
        () -> Void = {}


    // MARK: - Init

    init(
        scene:
            SceneModel
    ) {

        self.scene =
            scene


        self.runtime =
            ApplicationShellRuntime(
                definition:
                    MSRUApplication
                        .definition,
                shell:
                    MSRUApplicationShellPresentation
                        .definition
            )
    }


    // MARK: - Platform Action Installation

    func installShellActions(
        toggleQueue:
            @escaping () -> Void
    ) {

        toggleQueueAction =
            toggleQueue
    }


    // MARK: - Resolution

    func resolve()
        -> ResolvedApplicationShell {

        runtime.resolve(
            route:
                scene
                    .navigation
                    .route,
            workspaceContext:
                scene,
            shellContext:
                makeShellContext()
        )
    }


    // MARK: - Shell Context

    private func makeShellContext()
        -> MSRUApplicationShellContext {

        MSRUApplicationShellContext(
            scene:
                scene,
            actions:
                .init(
                    toggleQueue: {
                        [weak self]
                        in

                        self?
                            .toggleQueueAction()
                    }
                )
        )
    }
}
