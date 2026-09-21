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
                    group: "Source & Import",
                    title: "Add Music",
                    systemImage: "plus.circle",
                    route: .section(.addMusic),
                    order: 200
                ),
                SidebarContribution(
                    id: "metadata-center",
                    group: "Metadata",
                    title: "Metadata Center",
                    systemImage: "sparkles.rectangle.stack",
                    route: .section(.importReview),
                    order: 300
                )
            ],
            routes: [
                RouteContribution(
                    id: "add-music",
                    route: .section(.addMusic)
                ),
                RouteContribution(
                    id: "import-review",
                    route: .section(.importReview)
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
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: "Add Music",
                        systemImage: "plus.circle"
                    )
                ) { _ in
                    AddMusicView(
                        localStore: scene.application.localLibrary,
                        appleMusicStore: scene.application.musicLibrary,
                        onOpenLibrary: {
                            scene.send(.navigate(.section(.library)))
                        }
                    )
                }
            },
            RouteDestination(
                id: "import-review",
                route: .section(.importReview)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: "Metadata Center",
                        systemImage: "sparkles.rectangle.stack"
                    )
                ) { _ in
                    MetadataManagerWorkspaceView(
                        localStore: scene.application.localLibrary,
                        watchedFolders: scene.application.watchedFolders,
                        onOpenLibrary: {
                            scene.send(.navigate(.section(.library)))
                        }
                    )
                }
            }
        ]
    }
}
