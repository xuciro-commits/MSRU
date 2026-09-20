//
//  AlbumsFeature.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

enum AlbumsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "albums",
                    group: "资料库",
                    title: "专辑",
                    systemImage: "square.stack",
                    route: .section(.albums),
                    order: 110
                )
            ],
            routes: [
                RouteContribution(
                    id: "albums",
                    route: .section(.albums)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "albums",
                route: .section(.albums)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: "专辑",
                        systemImage: "square.stack"
                    )
                ) { _ in
                    AlbumsView(
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
