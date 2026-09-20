//
//  ListenNowFeature.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

enum ListenNowFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "listen-now",
                    group: "发现",
                    title: "现在收听",
                    systemImage: "play.circle",
                    route: .section(.listenNow),
                    order: 10
                )
            ],
            routes: [
                RouteContribution(
                    id: "listen-now",
                    route: .section(.listenNow)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "listen-now",
                route: .section(.listenNow)
            ) { scene in
                ListenNowView(
                    store: scene.application.musicCatalog,
                    onSelect: { item in
                        scene.selectedMusicContent = item
                    }
                )
            }
        ]
    }
}
