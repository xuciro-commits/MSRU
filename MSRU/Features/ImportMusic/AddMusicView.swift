//
//  AddMusicView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import Observation
import AppFoundationUI


struct AddMusicView: View {

    @Bindable var localStore:
        LocalLibraryStore

    @Bindable var appleMusicStore:
        AppleMusicLibraryStore

    let onOpenLibrary:
        () -> Void


    @State private var route:
        Route = .root

    @State private var isFileImporterPresented =
        false


    var body: some View {

        Group {

            switch route {

            case .root:

                rootContent

            case .appleMusic:

                appleMusicContent
            }
        }
        .fileImporter(
            isPresented:
                $isFileImporterPresented,
            allowedContentTypes:
                LocalAudioFormatSupport
                    .importContentTypes,
            allowsMultipleSelection:
                true
        ) { result in

            switch result {

            case .success(
                let urls
            ):

                Task {

                    await localStore
                        .importFiles(
                            urls
                        )

                    onOpenLibrary()
                }


            case .failure(
                let error
            ):
                if (error as? CocoaError)?.code != .userCancelled {
                    print(
                        "Add Music file importer failed:",
                        error.localizedDescription
                    )
                }
            }
        }
    }


    private var rootContent:
        some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 26
            ) {

                header


                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 280,
                                maximum: 420
                            ),
                            spacing: 18
                        )
                    ],
                    spacing: 18
                ) {

                    actionCard(
                        title:
                            "Files",
                        description:
                            "Import audio files into MSRU Library.",
                        systemImage:
                            "doc.badge.plus",
                        status:
                            "Available",
                        isEnabled:
                            true
                    ) {

                        isFileImporterPresented =
                            true
                    }


                    actionCard(
                        title:
                            "Folders",
                        description:
                            "Add folders to use as library sources.",
                        systemImage:
                            "folder.badge.plus",
                        status:
                            "Available",
                        isEnabled:
                            true
                    ) {
                        isFileImporterPresented =
                            true
                    }


                    actionCard(
                        title:
                            "Apple Music",
                        description:
                            "Connect or import albums, artists, and songs via Apple Music.",
                        systemImage:
                            "apple.logo",
                        status:
                            "Official Integration",
                        isEnabled:
                            true
                    ) {

                        route =
                            .appleMusic
                    }


                    actionCard(
                        title:
                            "Provider Library",
                        description:
                            "Import saved music from connected providers into the unified library.",
                        systemImage:
                            "rectangle.stack.badge.plus",
                        status:
                            "Requires Provider",
                        isEnabled:
                            false
                    ) {}
                }
            }
            .padding(28)
        }
        .hideScrollIndicatorsCompletely()
    }


    private var header:
        some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            Text("Add Music")
                .font(.largeTitle.bold())

            Text(
                "Import local media, or import music from connected services."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }


    private var appleMusicContent:
        some View {

        VStack(
            spacing: 0
        ) {

            HStack {

                Button {

                    route =
                        .root

                } label: {

                    Label(
                        "Add Music",
                        systemImage:
                            "chevron.left"
                    )
                }
                .buttonStyle(.plain)


                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)


            AppleMusicImportView(
                store:
                    appleMusicStore,
                onImportCompleted: {

                    onOpenLibrary()
                }
            )
        }
    }


    private func actionCard(
        title: String,
        description: String,
        systemImage: String,
        status: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button {

            action()

        } label: {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                HStack {

                    Image(
                        systemName:
                            systemImage
                    )
                    .font(.title2)


                    Spacer()


                    Text(
                        LocalizedStringKey(
                            status
                        )
                    )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            .quaternary,
                            in: Capsule()
                        )
                }


                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(
                        LocalizedStringKey(
                            title
                        )
                    )
                        .font(.title3.bold())

                    Text(
                        LocalizedStringKey(
                            description
                        )
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }


                HStack {

                    Text(
                        LocalizedStringKey(
                            isEnabled
                            ? "Open"
                            : "Unavailable"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)


                    Spacer()


                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
            .frame(
                maxWidth: .infinity,
                minHeight: 180,
                alignment: .topLeading
            )
            .background(
                .quaternary,
                in:
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}


private extension AddMusicView {

    enum Route {
        case root
        case appleMusic
    }
}


#Preview {
    AddMusicView(
        localStore:
            MSRUPreviewData.makeLocalLibraryStore(),
        appleMusicStore:
            MSRUPreviewData.makeAppleMusicStore(),
        onOpenLibrary: {}
    )
    .frame(
        width: 1000,
        height: 700
    )
}
