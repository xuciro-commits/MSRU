//
//  ArtistsFeature.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

enum ArtistsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "artists",
                    group: "Library",
                    title: "Artists",
                    systemImage: "music.mic",
                    route: .section(.artists),
                    order: 120
                )
            ],
            routes: [
                RouteContribution(
                    id: "artists",
                    route: .section(.artists)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "artists",
                route: .section(.artists)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Artists"),
                        systemImage: "music.mic"
                    )
                ) { _ in
                    ArtistsView(
                        localStore: scene.application.localLibrary,
                        playback: scene.application.playback,
                        onSelectTrack: { track in
                            scene.select(localTrack: track)
                        },
                        onAddMusic: {
                            scene.send(.navigate(.section(.addMusic)))
                        }
                    )
                }
            }
        ]
    }
}
