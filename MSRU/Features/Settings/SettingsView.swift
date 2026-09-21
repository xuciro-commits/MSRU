//
//  SettingsView.swift
//  MSRU
//

import SwiftUI
import Observation
import UniformTypeIdentifiers
import AppFoundation
import AppFoundationUI


struct SettingsView:
    View {

    @Bindable var playback:
        PlaybackController


    @Bindable var providerManager:
        ProviderManagerStore


    @Bindable var languageSettings:
        LanguageSettings

    @Bindable var watchedFolders:
        WatchedFolderStore

    @Environment(\.openURL)
    private var openURL

    @State private var isFolderPickerPresented:
        Bool = false

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


        case .library:
            watchedFoldersSection


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


    // MARK: - Watched Folders

    private var watchedFoldersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Watched Folders"))
                            .font(.headline)
                        Text(LocalizedStringKey("MSRU automatically monitors these directories in the background. Any new or modified audio files will be incrementally ingested."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        isFolderPickerPresented = true
                    } label: {
                        Label(LocalizedStringKey("Add Folder"), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let msg = watchedFolders.statusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(LocalizedStringKey(msg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            if watchedFolders.folders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey("No Watched Folders Configured"))
                        .font(.headline)
                    Text(LocalizedStringKey("Click 'Add Folder' to select a local directory to watch."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            } else {
                ForEach(watchedFolders.folders) { folder in
                    watchedFolderCard(folder)
                }
            }

            HStack {
                if watchedFolders.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text(LocalizedStringKey("Scanning watched folders…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await watchedFolders.rescanAll()
                    }
                } label: {
                    Label(LocalizedStringKey("Rescan All"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(watchedFolders.isScanning)
            }
        }
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    await watchedFolders.addFolder(url: url)
                }
            }
        }
    }

    private func watchedFolderCard(_ folder: WatchedFolder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(folder.isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(folder.displayName)
                            .font(.headline)

                        if folder.isEnabled {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text(LocalizedStringKey("Monitoring"))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                        } else {
                            Text(LocalizedStringKey("Paused"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 12) {
                        Text("\(folder.trackCount) " + String(localized: "tracks"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let lastScan = folder.lastScannedAt {
                            Text(String(localized: "Last scanned:") + " \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await watchedFolders.rescanFolder(id: folder.id)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Rescan this folder"))

                    Button {
                        openURL(folder.url)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Show in Finder"))

                    Button(role: .destructive) {
                        watchedFolders.removeFolder(id: folder.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Remove watched folder"))
                }
            }

            Divider()

            HStack {
                Toggle(LocalizedStringKey("Active Monitoring"), isOn: Binding(
                    get: { folder.isEnabled },
                    set: { _ in watchedFolders.toggleFolder(id: folder.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()

                Toggle(LocalizedStringKey("Auto-Ingest into Library"), isOn: Binding(
                    get: { folder.autoIngest },
                    set: { watchedFolders.setAutoIngest(id: folder.id, autoIngest: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
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
    let app = MSRUPreviewData.makeApplication()
    SettingsView(
        playback:
            app.playback,
        providerManager:
            app.providerManager,
        languageSettings:
            app.languageSettings,
        watchedFolders:
            app.watchedFolders
    )
    .frame(
        width:
            1000,
        height:
            700
    )
}
