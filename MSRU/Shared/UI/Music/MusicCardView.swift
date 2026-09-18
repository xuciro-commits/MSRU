//
//  MusicCardView.swift
//  MSRU
//

import SwiftUI


enum MusicCardStyle {

    case featured
    case standard
    case compact
}


struct MusicCardView: View {

    let item:
        MusicContent

    let style:
        MusicCardStyle


    var body: some View {

        switch style {

        case .featured:
            featuredCard

        case .standard:
            standardCard

        case .compact:
            compactCard
        }
    }


    // MARK: - Featured

    private var featuredCard:
        some View {

        ZStack(
            alignment:
                .bottomLeading
        ) {

            MusicArtworkView(
                url:
                    item.artworkURL,
                aspectRatio:
                    16 / 10,
                cornerRadius:
                    16
            )


            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.15),
                    .black.opacity(0.82)
                ],
                startPoint:
                    .top,
                endPoint:
                    .bottom
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {

                Text(
                    "FEATURED ALBUM"
                )
                .font(
                    .caption2.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .white.opacity(
                        0.72
                    )
                )


                Text(
                    item.title
                )
                .font(
                    .title3.bold()
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(2)


                if let subtitle =
                    item.subtitle {

                    Text(
                        subtitle
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .white.opacity(
                            0.76
                        )
                    )
                    .lineLimit(1)
                }
            }
            .padding(18)
        }
        .frame(
            width:
                360
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    16,
                style:
                    .continuous
            )
        )
    }


    // MARK: - Standard

    private var standardCard:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                7
        ) {

            MusicArtworkView(
                url:
                    item.artworkURL,
                cornerRadius:
                    10
            )


            Text(
                item.title
            )
            .font(
                .callout.weight(
                    .medium
                )
            )
            .lineLimit(1)


            if let subtitle =
                item.subtitle {

                Text(
                    subtitle
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
            }
        }
        .frame(
            width:
                180,
            alignment:
                .topLeading
        )
    }


    // MARK: - Compact

    private var compactCard:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                6
        ) {

            MusicArtworkView(
                url:
                    item.artworkURL,
                cornerRadius:
                    8
            )


            Text(
                item.title
            )
            .font(
                .caption.weight(
                    .medium
                )
            )
            .lineLimit(1)


            if let subtitle =
                    item.subtitle {

                Text(
                    subtitle
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
            }
        }
        .frame(
            width:
                140,
            alignment:
                .topLeading
        )
    }
}


// MARK: - Previews

#Preview("Music Cards") {

    ScrollView {

        VStack(
            alignment:
                .leading,
            spacing:
                32
        ) {

            MusicCardView(
                item:
                    MSRUPreviewData
                        .featuredAlbum,
                style:
                    .featured
            )


            HStack(
                alignment:
                    .top,
                spacing:
                    28
            ) {

                MusicCardView(
                    item:
                        MSRUPreviewData
                            .albumOne,
                    style:
                        .standard
                )


                MusicCardView(
                    item:
                        MSRUPreviewData
                            .albumFive,
                    style:
                        .standard
                )


                MusicCardView(
                    item:
                        MSRUPreviewData
                            .albumWithoutSubtitle,
                    style:
                        .compact
                )
            }
        }
        .padding(32)
    }
    .frame(
        width:
            760,
        height:
            650
    )
}
