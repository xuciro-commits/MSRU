//
//  SettingsView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary

struct SettingsView: View {
    @Bindable var providerManager: ProviderManagerStore
    @Bindable var languageSettings: LanguageSettings

    @State private var selection: SettingsCategory = .providers

    var body: some View {
        HStack(spacing: 0) {
            categoryList
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    content
                }
                .padding(28)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .hideScrollIndicatorsCompletely()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category Navigation

    @ViewBuilder
    private var categoryList: some View {
#if os(macOS)
        List(SettingsCategory.allCases, selection: $selection) { category in
            categoryLabel(category)
                .tag(category)
        }
        .listStyle(.sidebar)
        .hideScrollIndicatorsCompletely()
        .frame(width: 190)
#else
        // iOS has no List(data, selection:); selection stays owned here and rows are Buttons.
        List {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selection = category
                } label: {
                    HStack(spacing: 10) {
                        categoryLabel(category)
                        Spacer()
                        if selection == category {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .hideScrollIndicatorsCompletely()
        .frame(width: 210)
#endif
    }

    private func categoryLabel(_ category: SettingsCategory) -> some View {
        Label(LocalizedStringKey(category.title), systemImage: category.systemImage)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(selection.title))
                .font(.largeTitle.bold())
            Text(LocalizedStringKey(selection.subtitle))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .general:
            languagePicker
        case .providers:
            ProviderSettingsView(store: providerManager)
        }
    }

    // MARK: - Language Picker

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Language")
                .font(.headline)
            Picker("Language", selection: $languageSettings.selectedLanguage) {
                ForEach(SupportedLanguage.allCases) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Settings Category

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case providers

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "App behavior and appearance."
        case .providers: "Catalog, metadata, and playback providers."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .providers: "point.3.connected.trianglepath.dotted"
        }
    }
}

// MARK: - Provider Settings View

struct ProviderSettingsView: View {

    @Bindable var store: ProviderManagerStore
    @State private var isAddingProvider = false
    @State private var selectedProviderID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configured Providers").font(.title3.bold())
                    Text("Configure catalog, metadata, library, and playback capabilities separately.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isAddingProvider = true
                } label: {
                    Label("Add Provider", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            let providers = store.orderedProviders
            VStack(spacing: 0) {
                ForEach(providers) { provider in
                    HStack(alignment: .center, spacing: 14) {
                        Button {
                            selectedProviderID = provider.id
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: provider.systemImage)
                                    .font(.title2)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(LocalizedStringKey(provider.name)).font(.headline)
                                        Text(LocalizedStringKey(provider.healthTitle))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.quaternary, in: Capsule())
                                    }
                                    Text(LocalizedStringKey(provider.summary))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 6) {
                                        ForEach(provider.capabilities.sorted { $0.rawValue < $1.rawValue }) { capability in
                                            Text(LocalizedStringKey(capability.title))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(.quaternary, in: Capsule())
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Toggle(
                            "Enabled",
                            isOn: Binding(
                                get: { provider.isEnabled },
                                set: { store.setEnabled($0, id: provider.id) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(16)

                    if provider.id != providers.last?.id { Divider() }
                }
            }
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Playback Priority").font(.title3.bold())
                let playback = store.playbackProviders
                VStack(spacing: 0) {
                    ForEach(playback) { provider in
                        HStack(spacing: 12) {
                            Text("\(provider.priority)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                            Image(systemName: provider.systemImage).frame(width: 24)
                            Text(LocalizedStringKey(provider.name))
                            Spacer()
                            Text(provider.isEnabled ? LocalizedStringKey("Enabled") : LocalizedStringKey("Disabled"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        if provider.id != playback.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
        .sheet(isPresented: $isAddingProvider) {
            AddProviderView(store: store)
        }
        .sheet(isPresented: detailIsPresented) {
            if let selectedProviderID {
                ProviderDetailView(store: store, providerID: selectedProviderID)
            }
        }
    }

    private var detailIsPresented: Binding<Bool> {
        Binding(
            get: { selectedProviderID != nil },
            set: { if !$0 { selectedProviderID = nil } }
        )
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
                SettingsView(
                    providerManager: scene.application.providerManager,
                    languageSettings: scene.application.languageSettings
                )
            }
        ]
    }
}

// MARK: - Previews

#Preview {
    let app = MSRUPreviewData.makeApplication()
    SettingsView(
        providerManager: app.providerManager,
        languageSettings: app.languageSettings
    )
    .frame(width: 1000, height: 700)
}

#Preview("Provider Settings") {
    ProviderSettingsView(store: ProviderManagerStore(defaults: nil))
        .frame(width: 800, height: 600)
}
