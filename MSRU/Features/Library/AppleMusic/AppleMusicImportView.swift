//
//  AppleMusicImportView.swift
//  MSRU
//

import SwiftUI
import Observation


struct AppleMusicImportView: View {

    @Bindable var store:
        AppleMusicLibraryStore

    let onImportCompleted:
        () -> Void


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
                "Bring your Apple Music library into MSRU."
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
                    "Import Apple Music artists",
                description:
                    "Include artists from your Apple Music library.",
                isOn:
                    $options.importsArtists
            )


            Divider()


            importOption(
                title:
                    "Import Apple Music tracks",
                description:
                    "Include songs from your Apple Music library.",
                isOn:
                    $options.importsSongs
            )


            Divider()


            importOption(
                title:
                    "Import Apple Music albums",
                description:
                    "Include albums from your Apple Music library.",
                isOn:
                    $options.importsAlbums
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

                Text(title)
                    .font(
                        .headline
                    )


                Text(description)
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

            HStack(
                spacing: 10
            ) {

                ProgressView()
                    .controlSize(
                        .small
                    )


                Text(
                    "Importing Apple Music library…"
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(
                .bottom,
                12
            )

        } else if let error =
                    store.lastError {

            Text(error)
                .font(.callout)
                .foregroundStyle(
                    .red
                )
                .padding(
                    .bottom,
                    12
                )
        }
    }


    // MARK: - Footer

    private var footer:
        some View {

        HStack {

            if store.hasContent {

                Text(
                    "\(store.albumCount) albums · \(store.artistCount) artists · \(store.songCount) songs"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Button {
                Task {

                    let success =
                        await store
                            .importLibrary(
                                options:
                                    options
                            )


                    if success {
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


#Preview {
    AppleMusicImportView(
        store:
            MSRUPreviewData.makeAppleMusicStore(),
        onImportCompleted: {}
    )
    .frame(
        width: 900,
        height: 650
    )
}
