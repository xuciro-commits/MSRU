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
                    group: "工具",
                    title: "导入与审核",
                    systemImage: "tray.and.arrow.down",
                    route: .section(.addMusic),
                    order: 200
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
                        title: "导入与审核",
                        systemImage: "tray.and.arrow.down"
                    )
                ) { _ in
                    MetadataManagerWorkspaceView(
                        localStore: scene.application.localLibrary,
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
                        title: "导入与审核",
                        systemImage: "tray.and.arrow.down"
                    )
                ) { _ in
                    MetadataManagerWorkspaceView(
                        localStore: scene.application.localLibrary,
                        onOpenLibrary: {
                            scene.send(.navigate(.section(.library)))
                        }
                    )
                }
            }
        ]
    }
}
