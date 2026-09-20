//
//  LibraryFeature+Application.swift
//  MSRU
//

import Foundation
import AppFoundation


// MARK: - Application Contribution

extension LibraryFeature:
    ApplicationFeature {

    typealias Route =
        SceneRoute


    nonisolated static var contributions:
        FeatureContribution<Route> {

        FeatureContribution(
            sidebar: [

                SidebarContribution(
                    id:
                        "library",
                    group:
                        "Library",
                    title:
                        "Songs",
                    systemImage:
                        "music.note",
                    route:
                        SceneRoute
                            .section(
                                .library
                            ),
                    order:
                        100
                )
            ],

            routes: [

                RouteContribution(
                    id:
                        "library",
                    route:
                        SceneRoute
                            .section(
                                .library
                            )
                )
            ]
        )
    }
}
