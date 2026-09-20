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
                "导入 Apple Music"
            )
            .font(
                .largeTitle.bold()
            )


            Text(
                "将你的 Apple Music 资料库导入 MSRU。"
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
                    "导入 Apple Music 艺术家",
                description:
                    "包含 Apple Music 资料库中的艺术家。",
                isOn:
                    $options.importsArtists
            )


            Divider()


            importOption(
                title:
                    "导入 Apple Music 歌曲",
                description:
                    "包含 Apple Music 资料库中的歌曲。",
                isOn:
                    $options.importsSongs
            )


            Divider()


            importOption(
                title:
                    "导入 Apple Music 专辑",
                description:
                    "包含 Apple Music 资料库中的专辑。",
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
                    "正在导入 Apple Music 资料库…"
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
                    "\(store.albumCount) 张专辑 · \(store.artistCount) 位艺术家 · \(store.songCount) 首歌曲"
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
                    ? "正在导入…"
                    : "开始导入"
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
