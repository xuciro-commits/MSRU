//
//  MSRUApplicationShellPresentation.swift
//  MSRU
//

import SwiftUI

import AppFoundationUI


// MARK: - Shell Presentation Context

@MainActor
struct MSRUApplicationShellContext {

    let scene:
        SceneModel

    let actions:
        Actions


    struct Actions {

        let toggleQueue:
            () -> Void

        let revealInFinder:
            (URL) -> Void
    }
}


// MARK: - MSRU Application Shell Presentation

@MainActor
enum MSRUApplicationShellPresentation {

    private enum ID {

        static let contextSurface =
            "msru.context"

        static let miniPlayer =
            "playback.mini-player"

        static let toggleQueue =
            "playback.toggle-queue"
    }


    // MARK: - Context

    static let contextSurface =
        ContextPresentation<
            MSRUApplicationShellContext
        >(
            id:
                ID.contextSurface,
            role:
                .inspector
        ) {
            context in

            MSRUContextPaneView(
                scene:
                    context
                        .scene,
                onRevealInFinder:
                    context
                        .actions
                        .revealInFinder
            )
        }


    // MARK: - Application Accessory

    static let miniPlayer =
        AccessoryPresentation<
            MSRUApplicationShellContext
        >(
            id:
                ID.miniPlayer,
            scope:
                .application
        ) {
            context in

            MiniPlayerAccessoryView(
                playback:
                    context
                        .scene
                        .application
                        .playback,
                onToggleQueue:
                    context
                        .actions
                        .toggleQueue
            )
        }


    // MARK: - Application Toolbar

    static let toolbar =
        ToolbarPresentation<
            MSRUApplicationShellContext
        >(
            items:
                [
                    .action(
                        ToolbarActionPresentation(
                            id:
                                ID.toggleQueue,
                            title:
                                "Queue",
                            systemImage:
                                "list.bullet",
                            perform: {
                                context in

                                context
                                    .actions
                                    .toggleQueue()
                            }
                        )
                    )
                ]
        )


    // MARK: - Definition

    static let definition =
        ApplicationShellPresentation<
            MSRUApplicationShellContext
        >(
            contexts:
                [
                    contextSurface
                ],
            accessories:
                [
                    miniPlayer
                ],
            toolbar:
                toolbar
        )
}
