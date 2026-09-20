//
//  AddMusicFeature.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

enum AddMusicFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "add-music",
                    group: "Library",
                    title: "Add Music",
                    systemImage: "plus.square.on.square",
                    route: .section(.addMusic),
                    order: 20
                )
            ],
            routes: [
                RouteContribution(
                    id: "add-music",
                    route: .section(.addMusic)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "add-music",
                route: .section(.addMusic)
            ) { scene in
                AddMusicView(
                    localStore: scene.application.localLibrary,
                    appleMusicStore: scene.application.musicLibrary,
                    onOpenLibrary: {
                        scene.send(.navigate(.section(.library)))
                    }
                )
            }
        ]
    }
}
