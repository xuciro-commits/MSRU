//
//  BrowseFeature+Presentation.swift
//  MSRU
//

import SwiftUI

import AppFoundationUI


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
                                    "Browse",
                                systemImage:
                                    "square.grid.2x2"
                            )
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
}
