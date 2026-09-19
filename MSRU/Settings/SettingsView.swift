//
//  SettingsView.swift
//  MSRU
//

import SwiftUI
import Observation


struct SettingsView:
    View {

    @Bindable var playback:
        PlaybackController


    @Bindable var providerManager:
        ProviderManagerStore


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
            category.title,
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
                selection.title
            )
            .font(
                .largeTitle.bold()
            )


            Text(
                selection.subtitle
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

            settingsCard(
                title:
                    "Application",
                rows: [
                    (
                        "Appearance",
                        "System"
                    ),
                    (
                        "Window",
                        platformWindowDescription
                    ),
                    (
                        "Language",
                        "System"
                    )
                ]
            )


        case .library:

            settingsCard(
                title:
                    "Library",
                rows: [
                    (
                        "Current source",
                        "Local Files"
                    ),
                    (
                        "Imported media",
                        "Application Support / MSRU"
                    ),
                    (
                        "Unified library",
                        "Planned for remote sources"
                    )
                ]
            )


        case .playback:

            settingsCard(
                title:
                    "Playback",
                rows: [
                    (
                        "Preferred quality",
                        "Automatic"
                    ),
                    (
                        "Current provider",
                        playback
                            .currentProviderID?
                            .rawValue
                        ??
                        "None"
                    ),
                    (
                        "Resolution",
                        "Provider Kernel v1"
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
                            "Playback diagnostics",
                            "Available in kernel"
                        ),
                        (
                            "Provider health",
                            "Foundation ready"
                        ),
                        (
                            "Catalog cache",
                            "Enabled"
                        )
                    ]
                )


                Text(
                    "Interactive diagnostics controls will be connected after the front-end information architecture is stable."
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

        "Native macOS split view"

#else

        "Native Apple scene layout"

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
                title
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
                        row.0
                    )


                    Spacer()


                    Text(
                        row.1
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

            "Application behavior and appearance."


        case .library:

            "Storage, imports, and unified library behavior."


        case .playback:

            "Playback quality and resolution behavior."


        case .providers:

            "Catalog, metadata, and playback providers."


        case .advanced:

            "Diagnostics, health, and development tools."
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
            PlaybackController(),
        providerManager:
            ProviderManagerStore()
    )
    .frame(
        width:
            1000,
        height:
            700
    )
}
