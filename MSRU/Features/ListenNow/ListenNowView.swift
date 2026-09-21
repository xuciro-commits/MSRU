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

    @Environment(\.workspaceSafeAreaInsets)
    private var workspaceSafeArea


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
        .ignoresSafeArea(
            .all,
            edges:
                .trailing
        )
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
                    "Listen Now"
                )
                .font(
                    .largeTitle.bold()
                )


                Text(
                    "Discover music from \(store.selectedProvider.title)"
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
            .leading,
            28
        )
        .padding(
            .trailing,
            workspaceSafeArea.trailing + 28
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
                "Catalog Source"
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
                "Catalog: \(store.selectedProvider.title)",
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
                "Loading music…"
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
                "Unable to load music",
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
                    "Retry"
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
