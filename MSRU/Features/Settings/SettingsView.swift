//
//  SettingsView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback


struct SettingsView:
    View {

    @Bindable var playback:
        PlaybackController


    @Bindable var providerManager:
        ProviderManagerStore


    @Bindable var languageSettings:
        LanguageSettings

    @Environment(\.openURL)
    private var openURL

    @State private var selection:
        SettingsCategory =
            .providers


    var body:
        some View {

        HStack(
            spacing:
                0
        ) {

            categoryList


            Divider()


            ScrollView {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        24
                ) {

                    header


                    content
                }
                .padding(
                    28
                )
                .frame(
                    maxWidth:
                        900,
                    alignment:
                        .leading
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
            }
            .hideScrollIndicatorsCompletely()
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - Category Navigation

    @ViewBuilder
    private var categoryList:
        some View {

#if os(macOS)

        /*
         macOS List supports persistent single-selection
         semantics directly.
         */

        List(
            SettingsCategory
                .allCases,
            selection:
                $selection
        ) {
            category in

            categoryLabel(
                category
            )
            .tag(
                category
            )
        }
        .listStyle(
            .sidebar
        )
        .hideScrollIndicatorsCompletely()
        .frame(
            width:
                190
        )

#else

        /*
         iOS does not expose the macOS List(data, selection:)
         initializer.

         Keep the semantic selection owned by SettingsView
         and adapt row interaction with Buttons.
         */

        List {

            ForEach(
                SettingsCategory
                    .allCases
            ) {
                category in

                Button {

                    selection =
                        category

                } label: {

                    HStack(
                        spacing:
                            10
                    ) {

                        categoryLabel(
                            category
                        )


                        Spacer()


                        if selection
                            ==
                            category {

                            Image(
                                systemName:
                                    "checkmark"
                            )
                            .font(
                                .caption.bold()
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
        .listStyle(
            .sidebar
        )
        .hideScrollIndicatorsCompletely()
        .frame(
            width:
                210
        )

#endif
    }


    private func categoryLabel(
        _ category:
            SettingsCategory
    ) -> some View {

        Label(
            LocalizedStringKey(
                category.title
            ),
            systemImage:
                category.systemImage
        )
    }


    // MARK: - Header

    private var header:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {

            Text(
                LocalizedStringKey(
                    selection.title
                )
            )
            .font(
                .largeTitle.bold()
            )


            Text(
                LocalizedStringKey(
                    selection.subtitle
                )
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        switch selection {

        case .general:

            VStack(
                alignment:
                    .leading,
                spacing:
                    16
            ) {

                settingsCard(
                    title:
                        "App",
                    rows: [
                        (
                            "Appearance",
                            "System"
                        ),
                        (
                            "Window",
                            platformWindowDescription
                        )
                    ]
                )


                languagePicker
            }


        case .playback:

            settingsCard(
                title:
                    "Playback",
                rows: [
                    (
                        "Preferred Quality",
                        "Auto"
                    ),
                    (
                        "Current Provider",
                        playback
                            .currentProviderID?
                            .rawValue
                        ??
                        "None"
                    ),
                    (
                        "Resolution",
                        "Provider Core v1"
                    )
                ]
            )


        case .providers:

            ProviderSettingsView(
                store:
                    providerManager
            )


        case .advanced:

            VStack(
                alignment:
                    .leading,
                spacing:
                    14
            ) {

                settingsCard(
                    title:
                        "Diagnostics",
                    rows: [
                        (
                            "Playback Diagnostics",
                            "Core Provided"
                        ),
                        (
                            "Provider Status",
                            "Base Layer Ready"
                        ),
                        (
                            "Catalog Cache",
                            "Enabled"
                        )
                    ]
                )


                Text("Interactive diagnostic controls will be added once frontend info architecture is stable.")
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    // MARK: - Platform Description

    private var platformWindowDescription:
        String {

#if os(macOS)

        "Native macOS Split View"

#else

        "Native Apple Scene Layout"

#endif
    }


    // MARK: - Settings Card

    private func settingsCard(
        title:
            String,
        rows:
            [
                (
                    String,
                    String
                )
            ]
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {

            Text(
                LocalizedStringKey(
                    title
                )
            )
            .font(
                .title3.bold()
            )
            .padding(
                .bottom,
                12
            )


            ForEach(
                Array(
                    rows.enumerated()
                ),
                id:
                    \.offset
            ) {
                index,
                row in

                HStack {

                    Text(
                        LocalizedStringKey(
                            row.0
                        )
                    )


                    Spacer()


                    Text(
                        LocalizedStringKey(
                            row.1
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .vertical,
                    12
                )


                if index
                    <
                    rows.count - 1 {

                    Divider()
                }
            }
        }
        .padding(
            16
        )
        .background(
            .quaternary,
            in:
                RoundedRectangle(
                    cornerRadius:
                        14,
                    style:
                        .continuous
                )
        )
    }


    // MARK: - Language Picker

    private var languagePicker:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {

            Text(
                "Language"
            )
            .font(
                .headline
            )


            Picker(
                "Language",
                selection:
                    $languageSettings
                        .selectedLanguage
            ) {

                ForEach(
                    SupportedLanguage
                        .allCases
                ) { language in

                    Text(
                        language.displayName
                    )
                    .tag(
                        language
                    )
                }
            }
            .pickerStyle(
                .segmented
            )
            .labelsHidden()
        }
        .padding(
            16
        )
        .background(
            .quaternary,
            in:
                RoundedRectangle(
                    cornerRadius:
                        14,
                    style:
                        .continuous
                )
        )
    }

}


// MARK: - Settings Category

private enum SettingsCategory:
    String,
    CaseIterable,
    Identifiable {

    case general


    case playback

    case providers

    case advanced


    var id:
        Self {

        self
    }


    var title:
        String {

        switch self {

        case .general:

            "General"


        case .playback:

            "Playback"


        case .providers:

            "Providers"


        case .advanced:

            "Advanced"
        }
    }


    var subtitle:
        String {

        switch self {

        case .general:

            "App behavior and appearance."


        case .playback:

            "Playback quality and resolution behavior."


        case .providers:

            "Catalog, metadata, and playback providers."


        case .advanced:

            "Diagnostics, status, and developer tools."
        }
    }


    var systemImage:
        String {

        switch self {

        case .general:

            "gearshape"


        case .playback:

            "play.circle"


        case .providers:

            "point.3.connected.trianglepath.dotted"


        case .advanced:
            "wrench.and.screwdriver"
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
                    playback: scene.application.playback,
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
        playback: app.playback,
        providerManager: app.providerManager,
        languageSettings: app.languageSettings
    )
    .frame(width: 1000, height: 700)
}

#Preview("Provider Settings") {
    ProviderSettingsView(store: ProviderManagerStore(defaults: nil))
        .frame(width: 800, height: 600)
}
