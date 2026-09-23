//
//  SidebarPaneView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI

struct SidebarBottomAccessoryView: View {
    @Bindable var languageSettings: LanguageSettings
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text("许强")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .applyLocaleOverride(languageSettings.resolvedLocale)
    }
}

struct SidebarView: View {
    @Binding var selection: SceneRoute?
    let contributions: [SidebarContribution<SceneRoute>]

    var body: some View {
        ApplicationSidebar(
            selection: $selection,
            contributions: contributions
        )
    }
}

struct SidebarPaneView: View {
    @Bindable var scene: SceneModel

    var body: some View {
        SidebarView(
            selection: sidebarSelection,
            contributions: MSRUApplication.definition.sidebar
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .applyLocaleOverride(scene.application.languageSettings.resolvedLocale)
    }

    private var sidebarSelection: Binding<SceneRoute?> {
        Binding(
            get: {
                .section(scene.navigation.section)
            },
            set: { route in
                guard let route else { return }
                scene.send(.navigate(route))
            }
        )
    }
}

#Preview("Scene Navigation") {
    SidebarPaneView(scene: MSRUPreviewData.makeScene()).frame(width: 240, height: 600)
}

#Preview("Sidebar Parts") {
    @Previewable @State var selection: SceneRoute? = .section(.listenNow)
    let application = MSRUPreviewData.makeApplication()
    VStack {
        SidebarView(selection: $selection, contributions: MSRUApplication.definition.sidebar)
        SidebarBottomAccessoryView(languageSettings: application.languageSettings, onOpenSettings: {})
    }
    .frame(width: 240, height: 600)
}
