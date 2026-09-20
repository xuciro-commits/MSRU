//
//  BrowseFeature+Presentation.swift
//  MSRU
//

import SwiftUI

import AppFoundationUI
import AppFoundation


// MARK: - Application Presentation

extension BrowseFeature:
    ApplicationFeaturePresentation {

    typealias PresentationContext =
        SceneModel


    static var routeDestinations:
        [
            RouteDestination<
                SceneRoute,
                SceneModel
            >
        ] {

        [
            RouteDestination(
                id:
                    "browse",
                route:
                    .section(
                        .browse
                    ),
                workspace: {
                    scene in

                    WorkspacePresentation(
                        identity:
                            WorkspaceIdentity(
                                title:
                                    "浏览",
                                systemImage:
                                    "square.grid.2x2"
                            ),
                        toolbar:
                            browseToolbar
                    ) {
                        _ in

                        BrowseView(
                            feature:
                                scene.browse
                        )
                    }
                }
            )
        ]
    }


    // MARK: - Workspace Toolbar

    private static var browseToolbar:
        ToolbarPresentation<SceneModel> {

        ToolbarPresentation(
            items:
                [
                    .search(
                        ToolbarSearchPresentation(
                            id:
                                "browse.search",
                            prompt:
                                "搜索 Openverse",
                            text: {
                                scene in

                                scene
                                    .browse
                                    .state
                                    .query
                            },
                            update: {
                                scene,
                                value in

                                scene
                                    .browse
                                    .send(
                                        .queryChanged(
                                            value
                                        )
                                    )
                            }
                        )
                    )
                ]
        )
    }
}
