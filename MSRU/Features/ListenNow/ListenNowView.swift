//
//  ListenNowView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI


struct ListenNowView: View {

    @Bindable var store:
        MusicCatalogStore

    let onSelect:
        (MusicContent) -> Void


    var body: some View {

        ScrollView(showsIndicators: false) {

            LazyVStack(
                alignment:
                    .leading,
                spacing:
                    38
            ) {

                header

                content
            }
            .padding(
                .bottom,
                32
            )
        }
        .scrollIndicators(
            .hidden
        )
        .hideScrollIndicatorsCompletely()
        .task {

            await store
                .loadHomeIfNeeded()
        }
        .refreshable {

            await store
                .reloadHome()
        }
    }


    // MARK: - Header

    private var header:
        some View {

        HStack(
            alignment:
                .bottom
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                Text(
                    "现在收听"
                )
                .font(
                    .largeTitle.bold()
                )


                Text(
                    "发现来自 \(store.selectedProvider.title) 的音乐"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            providerMenu
        }
        .padding(
            .horizontal,
            28
        )
        .padding(
            .top,
            28
        )
    }


    // MARK: - Provider

    private var providerMenu:
        some View {

        Menu {

            Section(
                "目录来源"
            ) {

                ForEach(
                    MusicProviderID
                        .allCases
                ) { provider in

                    if store
                        .isProviderAvailable(
                            provider
                        ) {

                        Button {

                            Task {

                                await store
                                    .selectProvider(
                                        provider
                                    )
                            }

                        } label: {

                            Label(
                                provider.title,
                                systemImage:
                                    provider
                                        .systemImage
                            )
                        }

                    } else {

                        Button {

                        } label: {

                            VStack(
                                alignment:
                                    .leading
                            ) {

                                Text(
                                    provider.title
                                )


                                if let description =
                                    provider
                                        .availabilityDescription {

                                    Text(
                                        description
                                    )
                                }
                            }
                        }
                        .disabled(
                            true
                        )
                    }
                }
            }

        } label: {

            Label(
                "目录：\(store.selectedProvider.title)",
                systemImage:
                    store
                        .selectedProvider
                        .systemImage
            )
        }
        .menuStyle(
            .button
        )
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        if store.isLoading
            && store.sections.isEmpty {

            loading

        } else if
            let error =
                store.errorMessage,
            store.sections.isEmpty {

            errorView(
                error
            )

        } else {

            ForEach(
                store.sections
            ) { section in

                MusicSectionView(
                    section:
                        section,
                    onSelect: {
                        item in

                        onSelect(
                            item
                        )
                    }
                )
            }
        }
    }


    // MARK: - Loading

    private var loading:
        some View {

        VStack(
            spacing:
                12
        ) {

            ProgressView()


            Text(
                "正在加载音乐…"
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .vertical,
            100
        )
    }


    // MARK: - Error

    private func errorView(
        _ message:
            String
    ) -> some View {

        ContentUnavailableView {

            Label(
                "无法加载音乐",
                systemImage:
                    "wifi.exclamationmark"
            )

        } description: {

            Text(
                message
            )

        } actions: {

            Button {

                Task {

                    await store
                        .reloadHome()
                }

            } label: {

                Text(
                    "重试"
                )
            }
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .vertical,
            80
        )
    }
}


// MARK: - Preview

#Preview("Listen Now") {

    ListenNowView(
        store:
            MSRUPreviewData
                .makeCatalogStore(),
        onSelect: {
            _ in
        }
    )
    .frame(
        width:
            1100,
        height:
            800
    )
}
