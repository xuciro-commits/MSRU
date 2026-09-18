//
//  BrowseView.swift
//  MSRU
//

import SwiftUI
import Observation


struct BrowseView: View {

    let feature:
        FeatureHost<BrowseFeature>


    @Bindable
    private var state:
        BrowseFeature.State


    private let columns = [

        GridItem(
            .adaptive(
                minimum:
                    220,
                maximum:
                    300
            ),
            spacing:
                18
        )
    ]


    // MARK: - Init

    init(
        feature:
            FeatureHost<BrowseFeature>
    ) {

        self.feature =
            feature


        self._state =
            Bindable(
                wrappedValue:
                    feature.state
            )
    }


    // MARK: - Body

    var body: some View {

        ScrollView {

            LazyVStack(
                alignment:
                    .leading,
                spacing:
                    24
            ) {

                header

                searchBar

                sourceSummary

                content
            }
            .padding(28)
        }
        .task {

            feature
                .send(
                    .appeared
                )
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
                    "Browse"
                )
                .font(
                    .largeTitle.bold()
                )


                Text(
                    "Search openly licensed audio across connected catalog providers."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Label(
                "Openverse",
                systemImage:
                    "globe"
            )
            .font(
                .callout.weight(
                    .medium
                )
            )
        }
    }


    // MARK: - Search

    private var queryBinding:
        Binding<String> {

        Binding(
            get: {

                state.query
            },
            set: {
                value in

                feature
                    .send(
                        .queryChanged(
                            value
                        )
                    )
            }
        )
    }


    private var searchBar:
        some View {

        HStack(
            spacing:
                10
        ) {

            Image(
                systemName:
                    "magnifyingglass"
            )
            .foregroundStyle(
                .secondary
            )


            TextField(
                "Search songs, artists, recordings…",
                text:
                    queryBinding
            )
            .textFieldStyle(
                .plain
            )
            .font(
                .title3
            )


            if state.isLoading {

                ProgressView()
                    .controlSize(
                        .small
                    )
            }
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            11
        )
        .background(
            .quaternary,
            in:
                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
        )
    }


    // MARK: - Provider Summary

    private var sourceSummary:
        some View {

        HStack(
            spacing:
                14
        ) {

            Image(
                systemName:
                    "globe"
            )
            .font(
                .title2
            )
            .frame(
                width:
                    32
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Openverse"
                )
                .font(
                    .headline
                )


                Text(
                    "Catalog · artwork · license metadata · playback"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Text(
                "CATALOG + PLAYBACK"
            )
            .font(
                .caption2.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(16)
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


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        if state.isLoading
            && state.results.isEmpty {

            loadingState

        } else if
            let error =
                state.errorMessage,
            state.results.isEmpty {

            errorState(
                error
            )

        } else if state.results.isEmpty {

            ContentUnavailableView(
                "No Audio Found",
                systemImage:
                    "music.note",
                description:
                    Text(
                        "Try a different Openverse search."
                    )
            )
            .frame(
                maxWidth:
                    .infinity,
                minHeight:
                    300
            )

        } else {

            results
        }
    }


    // MARK: - Loading

    private var loadingState:
        some View {

        VStack(
            spacing:
                12
        ) {

            ProgressView()


            Text(
                "Searching Openverse…"
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity,
            minHeight:
                260
        )
    }


    // MARK: - Error

    private func errorState(
        _ error:
            String
    ) -> some View {

        ContentUnavailableView {

            Label(
                "Openverse Unavailable",
                systemImage:
                    "wifi.exclamationmark"
            )

        } description: {

            Text(
                error
            )

        } actions: {

            Button(
                "Try Again"
            ) {

                feature
                    .send(
                        .retryRequested
                    )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            minHeight:
                300
        )
    }


    // MARK: - Results

    private var results:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            HStack {

                Text(
                    "Openverse Results"
                )
                .font(
                    .title2.bold()
                )


                Spacer()


                Text(
                    "\(state.results.count) items"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            LazyVGrid(
                columns:
                    columns,
                alignment:
                    .leading,
                spacing:
                    18
            ) {

                ForEach(
                    state.results
                ) {
                    item in

                    audioCard(
                        item
                    )
                }
            }
        }
    }


    // MARK: - Audio Card

    private func audioCard(
        _ item:
            OpenverseAudio
    ) -> some View {

        let isCurrent =
            feature
                .isCurrent(
                    item
                )


        let isSaved =
            feature
                .isSaved(
                    item
                )


        return VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            artwork(
                item
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {

                Text(
                    item.title
                )
                .font(
                    .headline
                )
                .lineLimit(2)


                Text(
                    item.creatorTitle
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)


                Text(
                    item.summaryText
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(2)
            }


            metadata(
                item
            )


            HStack(
                spacing:
                    8
            ) {

                Button {

                    feature
                        .send(
                            .playPauseRequested(
                                item
                            )
                        )

                } label: {

                    Label(
                        isCurrent
                            && feature.isPlaying
                            ? "Pause"
                            : "Play",
                        systemImage:
                            isCurrent
                            && feature.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                }
                .buttonStyle(
                    .bordered
                )


                Spacer()


                if isSaved {

                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                }


                Menu {

                    actions(
                        for:
                            item
                    )

                } label: {

                    Image(
                        systemName:
                            "ellipsis"
                    )
                    .frame(
                        width:
                            24,
                        height:
                            22
                    )
                }
                .menuStyle(
                    .borderlessButton
                )
                .fixedSize()
            }
        }
        .padding(14)
        .background(
            .quaternary,
            in:
                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    16,
                style:
                    .continuous
            )
            .stroke(
                isCurrent
                    ? Color.primary.opacity(
                        0.24
                    )
                    : Color.clear,
                lineWidth:
                    1
            )
        }
        .contextMenu {

            actions(
                for:
                    item
            )
        }
    }


    // MARK: - Actions

    @ViewBuilder
    private func actions(
        for item:
            OpenverseAudio
    ) -> some View {

        Button {

            feature
                .send(
                    .playNextRequested(
                        item
                    )
                )

        } label: {

            Label(
                "Play Next",
                systemImage:
                    "text.line.first.and.arrowtriangle.forward"
            )
        }


        Button {

            feature
                .send(
                    .addToQueueRequested(
                        item
                    )
                )

        } label: {

            Label(
                "Add to Queue",
                systemImage:
                    "text.badge.plus"
            )
        }


        Divider()


        if feature.isSaved(
            item
        ) {

            Button {

                feature
                    .send(
                        .libraryToggleRequested(
                            item
                        )
                    )

            } label: {

                Label(
                    "Remove from Library",
                    systemImage:
                        "minus.circle"
                )
            }

        } else {

            Button {

                feature
                    .send(
                        .libraryToggleRequested(
                            item
                        )
                    )

            } label: {

                Label(
                    "Add to Library",
                    systemImage:
                        "plus.circle"
                )
            }
        }
    }


    // MARK: - Metadata

    private func metadata(
        _ item:
            OpenverseAudio
    ) -> some View {

        HStack(
            spacing:
                6
        ) {

            Text(
                item.sourceTitle
            )
            .lineLimit(1)


            Text(
                "·"
            )


            Text(
                item.licenseTitle
            )
            .lineLimit(1)


            if
                let duration =
                    item.durationText {

                Text(
                    "·"
                )


                Text(
                    duration
                )
                .monospacedDigit()
            }
        }
        .font(
            .caption2
        )
        .foregroundStyle(
            .tertiary
        )
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(
        _ item:
            OpenverseAudio
    ) -> some View {

        AsyncImage(
            url:
                item.thumbnailURL
        ) {
            phase in

            switch phase {

            case .success(
                let image
            ):

                image
                    .resizable()
                    .scaledToFill()


            default:

                artworkPlaceholder
            }
        }
        .frame(
            maxWidth:
                .infinity
        )
        .aspectRatio(
            1,
            contentMode:
                .fit
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    12,
                style:
                    .continuous
            )
        )
    }


    private var artworkPlaceholder:
        some View {

        ZStack {

            Rectangle()
                .fill(
                    .quaternary
                )


            Image(
                systemName:
                    "music.note"
            )
            .font(
                .largeTitle
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}


// MARK: - Preview

#Preview("Browse") {

    BrowseView(
        feature:
            MSRUPreviewData
                .makeBrowseFeature()
    )
    .frame(
        width:
            1100,
        height:
            800
    )
}
