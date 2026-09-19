//
//  LibraryFeature+Application.swift
//  MSRU
//

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
                        "Library",
                    systemImage:
                        "music.note.house",
                    route:
                        SceneRoute
                            .section(
                                .library
                            ),
                    order:
                        10
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
