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
                    "应用",
                rows: [
                    (
                        "外观",
                        "系统"
                    ),
                    (
                        "窗口",
                        platformWindowDescription
                    ),
                    (
                        "语言",
                        "系统"
                    )
                ]
            )


        case .library:

            settingsCard(
                title:
                    "资料库",
                rows: [
                    (
                        "当前来源",
                        "本地文件"
                    ),
                    (
                        "已导入媒体",
                        "Application Support / MSRU"
                    ),
                    (
                        "统一资料库",
                        "计划支持远程来源"
                    )
                ]
            )


        case .playback:

            settingsCard(
                title:
                    "播放",
                rows: [
                    (
                        "首选音质",
                        "自动"
                    ),
                    (
                        "当前服务提供方",
                        playback
                            .currentProviderID?
                            .rawValue
                        ??
                        "无"
                    ),
                    (
                        "解析度",
                        "服务提供方内核 v1"
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
                        "诊断",
                    rows: [
                        (
                            "播放诊断",
                            "内核已提供"
                        ),
                        (
                            "服务提供方状态",
                            "基础层已就绪"
                        ),
                        (
                            "目录缓存",
                            "已启用"
                        )
                    ]
                )


                Text(
                    "前端信息架构稳定后，将接入可交互的诊断控制。"
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

        "原生 macOS 分栏视图"

#else

        "原生 Apple 场景布局"

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

            "通用"


        case .library:

            "资料库"


        case .playback:

            "播放"


        case .providers:

            "服务提供方"


        case .advanced:

            "高级"
        }
    }


    var subtitle:
        String {

        switch self {

        case .general:

            "应用行为与外观。"


        case .library:

            "存储、导入和统一资料库行为。"


        case .playback:

            "播放音质与解析行为。"


        case .providers:

            "目录、元数据和播放服务提供方。"


        case .advanced:

            "诊断、状态和开发工具。"
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
            MSRUPreviewData.makeProviderStore()
    )
    .frame(
        width:
            1000,
        height:
            700
    )
}
