//
//  SettingsFeature.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

enum SettingsFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [],
            routes: [
                RouteContribution(
                    id: "settings",
                    route: .section(.settings)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "settings",
                route: .section(.settings)
            ) { scene in
                SettingsView(
                    playback: scene.application.playback,
                    providerManager: scene.application.providerManager,
                    languageSettings: scene.application.languageSettings
                )
            }
        ]
    }
}
