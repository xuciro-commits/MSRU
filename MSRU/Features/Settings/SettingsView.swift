//
//  SettingsView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation


struct SettingsView:
    View {

    @Bindable var playback:
        PlaybackController


    @Bindable var providerManager:
        ProviderManagerStore


    @Bindable var languageSettings:
        LanguageSettings


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
            .scrollIndicators(.hidden)
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
        .scrollIndicators(
            .hidden
        )
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
        .scrollIndicators(
            .hidden
        )
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


        case .library:

            settingsCard(
                title:
                    "Library",
                rows: [
                    (
                        "Current Source",
                        "Local Files"
                    ),
                    (
                        "Imported Media",
                        "Application Support / MSRU"
                    ),
                    (
                        "Unified Library",
                        "Remote sources planned"
                    )
                ]
            )


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


                Text(
                    "Interactive diagnostic controls will be added once frontend info architecture is stable."
                )
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

    case library

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


        case .library:

            "Library"


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


        case .library:

            "Storage, import, and unified library behavior."


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


        case .library:

            "music.note.house"


        case .playback:

            "play.circle"


        case .providers:

            "point.3.connected.trianglepath.dotted"


        case .advanced:

            "wrench.and.screwdriver"
        }
    }
}


#Preview {

    SettingsView(
        playback:
            MSRUPreviewData.makePlaybackController(),
        providerManager:
            MSRUPreviewData.makeProviderStore(),
        languageSettings:
            LanguageSettings()
    )
    .frame(
        width:
            1000,
        height:
            700
    )
}
