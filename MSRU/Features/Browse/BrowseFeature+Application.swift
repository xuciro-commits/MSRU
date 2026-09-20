//
//  BrowseFeature+Application.swift
//  MSRU
//

import AppFoundation


// MARK: - Application Contribution

extension BrowseFeature:
    ApplicationFeature {

    typealias Route =
        SceneRoute


    nonisolated static var contributions:
        FeatureContribution<Route> {

        FeatureContribution(
            sidebar: [

                SidebarContribution(
                    id:
                        "browse",
                    group:
                        "发现",
                    title:
                        "浏览",
                    systemImage:
                        "sparkles",
                    route:
                        SceneRoute
                            .section(
                                .browse
                            ),
                    order:
                        20
                )
            ],

            routes: [

                RouteContribution(
                    id:
                        "browse",
                    route:
                        SceneRoute
                            .section(
                                .browse
                            )
                )
            ]
        )
    }
}
