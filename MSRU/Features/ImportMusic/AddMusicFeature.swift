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
                    group: "来源与导入",
                    title: "添加音乐",
                    systemImage: "plus.circle",
                    route: .section(.addMusic),
                    order: 200
                ),
                SidebarContribution(
                    id: "metadata-center",
                    group: "元数据",
                    title: "元数据中心",
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
                        title: "添加音乐",
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
                        title: "元数据中心",
                        systemImage: "sparkles.rectangle.stack"
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
