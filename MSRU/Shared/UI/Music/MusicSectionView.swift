//
//  MusicSectionView.swift
//  MSRU
//

import SwiftUI
import AppFoundationUI


struct MusicSectionView: View {

    let section:
        MusicSection

    let onSelect:
        (MusicContent) -> Void


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            header

            content
        }
    }


    // MARK: - Header

    private var header:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                3
        ) {

            Text(
                section.title
            )
            .font(
                .title2.bold()
            )


            if let subtitle =
                section.subtitle {

                Text(
                    subtitle
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .horizontal,
            28
        )
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        switch section.layout {

        case .featured:

            horizontalShelf(
                style:
                    .featured,
                spacing:
                    18
            )


        case .shelf:

            horizontalShelf(
                style:
                    .standard,
                spacing:
                    16
            )


        case .compactShelf:

            horizontalShelf(
                style:
                    .compact,
                spacing:
                    14
            )


        case .grid:

            grid
        }
    }


    // MARK: - Shelf

    private func horizontalShelf(
        style:
            MusicCardStyle,
        spacing:
            CGFloat
    ) -> some View {

        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {

            LazyHStack(
                alignment:
                    .top,
                spacing:
                    spacing
            ) {

                ForEach(
                    section.items
                ) { item in

                    Button {

                        onSelect(
                            item
                        )

                    } label: {

                        MusicCardView(
                            item:
                                item,
                            style:
                                style
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }
            }
            .padding(
                .horizontal,
                28
            )
        }
        .scrollIndicators(
            .hidden
        )
        .hideScrollIndicatorsCompletely()
    }


    // MARK: - Grid

    private var grid:
        some View {

        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum:
                            160,
                        maximum:
                            200
                    ),
                    spacing:
                        18
                )
            ],
            alignment:
                .leading,
            spacing:
                24
        ) {

            ForEach(
                section.items
            ) { item in

                Button {

                    onSelect(
                        item
                    )

                } label: {

                    MusicCardView(
                        item:
                            item,
                        style:
                            .standard
                    )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
        .padding(
            .horizontal,
            28
        )
    }
}


// MARK: - Previews

#Preview("Section Presentations") {

    ScrollView {

        LazyVStack(
            alignment:
                .leading,
            spacing:
                40
        ) {

            MusicSectionView(
                section:
                    MSRUPreviewData
                        .featuredSection,
                onSelect: {
                    _ in
                }
            )


            MusicSectionView(
                section:
                    MSRUPreviewData
                        .shelfSection,
                onSelect: {
                    _ in
                }
            )


            MusicSectionView(
                section:
                    MSRUPreviewData
                        .compactSection,
                onSelect: {
                    _ in
                }
            )


            MusicSectionView(
                section:
                    MSRUPreviewData
                        .gridSection,
                onSelect: {
                    _ in
                }
            )
        }
        .padding(
            .vertical,
            28
        )
    }
    .frame(
        width:
            1100,
        height:
            900
    )
}
