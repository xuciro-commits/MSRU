//
//  MSRUApplicationShellPresentation.swift
//  MSRU
//

import SwiftUI

import AppFoundationUI


// MARK: - Shell Presentation Context

/// Runtime context available to application-level shell presentations.
///
/// Domain and scene state remain owned by `SceneModel`.
///
/// Shell-owned mechanics are exposed as semantic actions so product
/// presentation does not depend on AppKit window-controller behavior.
@MainActor
struct MSRUApplicationShellContext {

    let scene:
        SceneModel

    let actions:
        Actions


    // MARK: Actions

    struct Actions {

        let toggleQueue:
            () -> Void
    }
}


// MARK: - MSRU Application Shell Presentation

/// Product-level semantic description of MSRU's supporting surfaces.
///
/// This layer answers:
///
/// - what the surface means
/// - what scope it belongs to
/// - what product content it displays
///
/// It deliberately does not answer:
///
/// - which NSSplitViewItem hosts it
/// - where the accessory is attached
/// - how wide the context pane is
/// - how the presentation adapts on iPad
@MainActor
enum MSRUApplicationShellPresentation {


    // MARK: - Identifiers

    private enum ID {

        static let playbackQueue =
            "playback.queue"

        static let miniPlayer =
            "playback.mini-player"
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
            .scrollContentBackground(
                .hidden
            )
            .background(
                Color.clear
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
                ]
        )
}
