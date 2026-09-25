//
//  SettingsView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI

struct SettingsView: View {
    @Bindable var languageSettings: LanguageSettings

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $languageSettings.selectedLanguage) {
                    ForEach(SupportedLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Settings Feature Presentation

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
                SettingsView(languageSettings: scene.application.languageSettings)
            }
        ]
    }
}

// MARK: - Previews

#Preview {
    SettingsView(languageSettings: MSRUPreviewData.makeApplication().languageSettings)
        .frame(width: 600, height: 400)
}
