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
    }
}


// MARK: - MSRU Application Shell Presentation

@MainActor
enum MSRUApplicationShellPresentation {

    private enum ID {

        static let playbackQueue =
            "playback.queue"

        static let miniPlayer =
            "playback.mini-player"

        static let toggleQueue =
            "playback.toggle-queue"
    }


    // MARK: - Context

    static let playbackQueue =
        ContextPresentation<
            MSRUApplicationShellContext
        >(
            id:
                ID.playbackQueue,
            role:
                .activity
        ) {
            context in

            QueuePaneView(
                playback:
                    context
                        .scene
                        .application
                        .playback
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
                    playbackQueue
                ],
            accessories:
                [
                    miniPlayer
                ],
            toolbar:
                toolbar
        )
}
