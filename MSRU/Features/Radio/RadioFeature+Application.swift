//
//  RadioFeature+Application.swift
//  MSRU
//

import Foundation
import AppFoundation

// MARK: - Application Contribution

extension RadioFeature: ApplicationFeature {

    typealias Route = SceneRoute

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "radio",
                    group: "Discover",
                    title: "Radio",
                    systemImage: "dot.radiowaves.left.and.right",
                    route: SceneRoute.section(.radio),
                    order: 30
                )
            ],
            routes: [
                RouteContribution(
                    id: "radio",
                    route: SceneRoute.section(.radio)
                )
            ]
        )
    }
}
