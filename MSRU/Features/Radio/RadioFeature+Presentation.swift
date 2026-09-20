//
//  RadioFeature+Presentation.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

// MARK: - Application Presentation

extension RadioFeature: ApplicationFeaturePresentation {

    typealias PresentationContext = SceneModel

    static var routeDestinations: [RouteDestination<SceneRoute, SceneModel>] {
        [
            RouteDestination(
                id: "radio",
                route: .section(.radio),
                workspace: { scene in
                    WorkspacePresentation(
                        identity: WorkspaceIdentity(
                            title: String(localized: "Radio"),
                            systemImage: "dot.radiowaves.left.and.right"
                        ),
                        toolbar: radioToolbar
                    ) { _ in
                        RadioView(
                            feature: scene.radioFeature,
                            selectedStation: scene.selectedRadioStation,
                            onSelectStation: { station in
                                scene.select(radioStation: station)
                            }
                        )
                    }
                }
            )
        ]
    }

    // MARK: - Workspace Toolbar

    private static var radioToolbar: ToolbarPresentation<SceneModel> {
        ToolbarPresentation(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "radio.search",
                        prompt: String(localized: "Search stations, genres, or countries"),
                        text: { scene in
                            scene.radioFeature.state.searchQuery
                        },
                        update: { scene, value in
                            scene.radioFeature.send(
                                .searchQueryChanged(value)
                            )
                        }
                    )
                )
            ]
        )
    }
}
