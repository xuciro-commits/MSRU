//
//  AppleMusicImportView.swift
//  MSRU
//

import SwiftUI
import Observation
import MusicLibrary


struct AppleMusicImportView: View {

    @Bindable var store:
        AppleMusicLibraryStore

    @Bindable var localStore:
        LocalLibraryStore

    var playlistStore:
        PlaylistStore? = nil

    let onImportCompleted:
        () -> Void

    @Environment(\.openURL)
    private var openURL

    @State private var options =
        LibraryImportOptions()


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            header

            Divider()

            optionsContent

            Spacer()

            status

            footer
        }
        .padding(28)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Header

    private var header:
        some View {

        VStack(
            alignment: .leading,
            spacing: 6
        ) {

            Text(
                "Import Apple Music"
            )
            .font(
                .largeTitle.bold()
            )


            Text(
                "Import your Apple Music library into MSRU."
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .bottom,
            24
        )
    }


    // MARK: - Options

    private var optionsContent:
        some View {

        VStack(
            spacing: 0
        ) {

            importOption(
                title:
                    "Import Apple Music Artists",
                description:
                    "Include artists from Apple Music library.",
                isOn:
                    $options.importsArtists
            )


            Divider()


            importOption(
                title:
                    "Import Apple Music Songs",
                description:
                    "Include songs from Apple Music library.",
                isOn:
                    $options.importsSongs
            )


            Divider()

            importOption(
                title:
                    "Import Apple Music Albums",
                description:
                    "Include albums from Apple Music library.",
                isOn:
                    $options.importsAlbums
            )

            Divider()

            importOption(
                title:
                    "Import Apple Music Playlists",
                description:
                    "Include user playlists from Apple Music library.",
                isOn:
                    $options.importsPlaylists
            )
        }
        .padding(.vertical, 10)
    }


    private func importOption(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {

        HStack(
            alignment: .center,
            spacing: 20
        ) {

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(LocalizedStringKey(title))
                    .font(
                        .headline
                    )


                Text(LocalizedStringKey(description))
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .secondary
                    )
            }


            Spacer()


            Toggle(
                "",
                isOn: isOn
            )
            .labelsHidden()
            .toggleStyle(
                .switch
            )
        }
        .padding(
            .vertical,
            18
        )
    }


    // MARK: - Status

    @ViewBuilder
    private var status:
        some View {

        if store.isImporting {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                HStack(
                    spacing: 10
                ) {

                    ProgressView()
                        .controlSize(
                            .small
                        )

                    Text(
                        store.importStatusText.isEmpty
                        ? "Importing Apple Music library…"
                        : store.importStatusText
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
                }

                ProgressView(
                    value: store.importProgress
                )
                .progressViewStyle(
                    .linear
                )
            }
            .padding(
                .bottom,
                16
            )

        } else if let error =
                    store.lastError {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                HStack(
                    spacing: 8
                ) {

                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )

                    Text(error)
                        .font(.callout)
                        .foregroundStyle(
                            .primary
                        )
                }

                if store.isAuthorizationDenied {

                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media") {
                            openURL(url)
                        }
                    } label: {

                        Label(
                            "Open System Settings",
                            systemImage: "gear"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                .quaternary.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .padding(
                .bottom,
                16
            )

        } else if store.importedTrackCount > 0 {

            HStack(
                spacing: 10
            ) {

                Image(
                    systemName:
                        "checkmark.circle.fill"
                )
                .foregroundStyle(
                    .green
                )

                Text(
                    "Successfully imported \(store.importedTrackCount) songs into your library!"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(
                .bottom,
                16
            )
        }
    }


    // MARK: - Footer

    private var footer:
        some View {

        HStack {

            if store.hasContent {

                Text(
                    "\(store.albumCount) Albums · \(store.artistCount) Artists · \(store.songCount) Songs · \(store.playlistCount) Playlists"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if store.importedTrackCount > 0 && !store.isImporting {

                Button {

                    onImportCompleted()
                } label: {

                    Label(
                        "View in Library",
                        systemImage: "music.note.list"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(
                    .large
                )

            } else {

                Button {

                    Task {

                        let success =
                            await store
                                .importLibrary(
                                    options:
                                        options,
                                    into:
                                        localStore,
                                    playlistStore:
                                        playlistStore
                                )

                        if success && store.importedTrackCount > 0 {
                            onImportCompleted()
                        }
                    }
                } label: {

                    Text(
                        store.isImporting
                        ? "Importing…"
                        : "Start Import"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(
                    .large
                )
                .disabled(
                    !options.hasSelection
                    || store.isImporting
                )
            }
        }
    }
}


#Preview {
    AppleMusicImportView(
        store:
            MSRUPreviewData.makeAppleMusicStore(),
        localStore:
            MSRUPreviewData.makeLocalLibraryStore(),
        onImportCompleted: {}
    )
    .frame(
        width: 900,
        height: 650
    )
}
