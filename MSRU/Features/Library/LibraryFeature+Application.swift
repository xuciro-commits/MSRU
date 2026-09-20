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
                        "资料库",
                    title:
                        "歌曲",
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
