//
//  MSRUApplicationShellSession.swift
//  MSRU
//

import Foundation
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


    // MARK: - Resolver

    private let resolver:
        ApplicationShellResolver<
            SceneRoute,
            SceneModel,
            MSRUApplicationShellContext
        >


    // MARK: - Platform Actions

    private var toggleQueueAction:
        () -> Void = {}

    private var revealInFinderAction:
        (URL) -> Void = { _ in }


    // MARK: - Init

    init(
        scene:
            SceneModel
    ) {

        self.scene =
            scene


        self.resolver =
            ApplicationShellResolver(
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
            @escaping () -> Void,
        revealInFinder:
            @escaping (URL) -> Void = { _ in }
    ) {

        toggleQueueAction =
            toggleQueue

        revealInFinderAction =
            revealInFinder
    }


    // MARK: - Resolution

    func resolve()
        -> ResolvedApplicationShell {

        resolver.resolve(
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
                    },
                    revealInFinder: {
                        [weak self]
                        url in

                        self?
                            .revealInFinderAction(
                                url
                            )
                    }
                )
        )
    }
}
