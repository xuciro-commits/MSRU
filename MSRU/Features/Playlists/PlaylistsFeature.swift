//
//  PlaylistsFeature.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

enum PlaylistsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "playlists",
                    group: "Library",
                    title: "Playlists",
                    systemImage: "music.note.list",
                    route: .section(.playlists),
                    order: 115
                )
            ],
            routes: [
                RouteContribution(
                    id: "playlists",
                    route: .section(.playlists)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "playlists",
                route: .section(.playlists)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Playlists"),
                        systemImage: "music.note.list"
                    )
                ) { _ in
                    PlaylistsView(
                        playlistStore: scene.application.playlistStore,
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        }
                    )
                }
            }
        ]
    }
}
