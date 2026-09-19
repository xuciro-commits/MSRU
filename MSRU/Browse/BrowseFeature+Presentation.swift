//
//  BrowseFeature+Presentation.swift
//  MSRU
//

import AppFoundationUI
import SwiftUI


// MARK: - Application Presentation

extension BrowseFeature:
    ApplicationFeaturePresentation {

    typealias PresentationContext =
        SceneModel


    @MainActor
    static var routeDestinations:
        [
            RouteDestination<
                Route,
                PresentationContext
            >
        ] {

        [

            RouteDestination(
                id:
                    "browse",
                route:
                    SceneRoute
                        .section(
                            .browse
                        )
            ) {
                scene in

                BrowseView(
                    feature:
                        scene
                            .browse
                )
            }
        ]
    }
}
