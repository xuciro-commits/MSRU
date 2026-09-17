//
//  MusicArtworkView.swift
//  MSRU
//

import SwiftUI


struct MusicArtworkView: View {

    let url:
        URL?

    var aspectRatio:
        CGFloat = 1

    var cornerRadius:
        CGFloat = 10


    var body: some View {

        GeometryReader {
            geometry in

            artwork
                .frame(
                    width:
                        geometry.size.width,
                    height:
                        geometry.size.height
                )
                .clipped()
        }
        .aspectRatio(
            aspectRatio,
            contentMode:
                .fit
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    cornerRadius,
                style:
                    .continuous
            )
        )
    }


    // MARK: - Artwork

    @ViewBuilder
    private var artwork:
        some View {

        if let url {

            AsyncImage(
                url: url,
                transaction:
                    Transaction(
                        animation:
                            .easeOut(
                                duration:
                                    0.2
                            )
                    )
            ) {
                phase in

                switch phase {

                case .empty:

                    placeholder
                        .overlay {

                            ProgressView()
                                .controlSize(
                                    .small
                                )
                        }


                case .success(
                    let image
                ):

                    image
                        .resizable()
                        .scaledToFill()


                case .failure:

                    placeholder


                @unknown default:

                    placeholder
                }
            }

        } else {

            placeholder
        }
    }


    // MARK: - Placeholder

    private var placeholder:
        some View {

        Rectangle()
            .fill(
                .quaternary
            )
            .overlay {

                Image(
                    systemName:
                        "music.note"
                )
                .font(
                    .title2
                )
                .foregroundStyle(
                    .secondary
                )
            }
    }
}


#Preview {

    VStack {

        MusicArtworkView(
            url: nil
        )
        .frame(
            width: 180
        )


        MusicArtworkView(
            url: nil,
            aspectRatio:
                16 / 10
        )
        .frame(
            width: 360
        )
    }
    .padding()
}
