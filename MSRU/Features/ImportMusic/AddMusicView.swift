//
//  AddMusicView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import Observation


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

                print(
                    "Add Music file importer failed:",
                    error
                )
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
                            "文件",
                        description:
                            "将音频文件导入 MSRU 资料库。",
                        systemImage:
                            "doc.badge.plus",
                        status:
                            "可用",
                        isEnabled:
                            true
                    ) {

                        isFileImporterPresented =
                            true
                    }


                    actionCard(
                        title:
                            "文件夹",
                        description:
                            "添加文件夹并将其作为资料库来源。",
                        systemImage:
                            "folder.badge.plus",
                        status:
                            "可用",
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
                            "通过官方 Apple Music 途径连接或导入专辑、艺术家和歌曲。",
                        systemImage:
                            "apple.logo",
                        status:
                            "官方集成",
                        isEnabled:
                            true
                    ) {

                        route =
                            .appleMusic
                    }


                    actionCard(
                        title:
                            "服务提供方资料库",
                        description:
                            "将已连接服务提供方中的已保存音乐导入统一资料库。",
                        systemImage:
                            "rectangle.stack.badge.plus",
                        status:
                            "需要服务提供方",
                        isEnabled:
                            false
                    ) {}
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }


    private var header:
        some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            Text("添加音乐")
                .font(.largeTitle.bold())

            Text(
                "导入本地媒体，或从已连接的服务中导入音乐。"
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
                        "添加音乐",
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


                    Text(status)
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

                    Text(title)
                        .font(.title3.bold())

                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }


                HStack {

                    Text(
                        isEnabled
                        ? "打开"
                        : "暂不可用"
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
