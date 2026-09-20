//
//  MusicLibraryView.swift
//  MSRU
//

import SwiftUI
import MusicKit
import Observation


struct MusicLibraryView: View {

    enum Section:
        String,
        CaseIterable,
        Identifiable {

        case albums = "专辑"
        case artists = "艺术家"
        case songs = "歌曲"


        var id: Self {
            self
        }
    }


    @Bindable var store:
        AppleMusicLibraryStore


    @State private var selection:
        Section = .albums


    var body: some View {

        VStack(
            spacing: 0
        ) {

            header

            Divider()

            content
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Header

    private var header:
        some View {

        HStack {

            Text("资料库")
                .font(
                    .largeTitle.bold()
                )


            Spacer()


            Picker(
                "资料库分区",
                selection:
                    $selection
            ) {

                ForEach(
                    Section.allCases
                ) { section in

                    Text(
                        section.rawValue
                    )
                    .tag(section)
                }
            }
            .pickerStyle(
                .segmented
            )
            .frame(
                width: 280
            )
        }
        .padding(
            .horizontal,
            28
        )
        .padding(
            .vertical,
            20
        )
    }


    // MARK: - Content

    @ViewBuilder
    private var content:
        some View {

        if !store.hasContent {

            ContentUnavailableView(
                "没有已导入的音乐",
                systemImage:
                    "music.note.house",
                description:
                    Text(
                        "导入 Apple Music 资料库后即可开始浏览。"
                    )
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

        } else {

            switch selection {

            case .albums:
                albumsView

            case .artists:
                artistsView

            case .songs:
                songsView
            }
        }
    }


    // MARK: - Albums

    private var albumsView:
        some View {

        ScrollView {

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: 150,
                            maximum: 200
                        ),
                        spacing: 18
                    )
                ],
                alignment: .leading,
                spacing: 24
            ) {

                ForEach(
                    store.albums
                ) { album in

                    albumCard(
                        album
                    )
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }


    private func albumCard(
        _ album: Album
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            artwork(
                album.artwork,
                cornerRadius: 10
            )


            Text(
                album.title
            )
            .font(
                .callout.weight(
                    .medium
                )
            )
            .lineLimit(1)


            Text(
                album.artistName
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
        }
    }


    // MARK: - Artists

    private var artistsView:
        some View {

        ScrollView {

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: 130,
                            maximum: 170
                        ),
                        spacing: 22
                    )
                ],
                alignment: .leading,
                spacing: 26
            ) {

                ForEach(
                    store.artists
                ) { artist in

                    VStack(
                        spacing: 9
                    ) {

                        artwork(
                            artist.artwork,
                            cornerRadius: 999
                        )


                        Text(
                            artist.name
                        )
                        .font(
                            .callout.weight(
                                .medium
                            )
                        )
                        .lineLimit(1)
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }


    // MARK: - Songs

    private var songsView:
        some View {

        List(
            store.songs
        ) { song in

            HStack(
                spacing: 10
            ) {

                songArtwork(
                    song.artwork
                )


                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        song.title
                    )
                    .lineLimit(1)


                    Text(
                        song.artistName
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }


                Spacer()


                if let albumTitle =
                    song.albumTitle {

                    Text(
                        albumTitle
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .tertiary
                    )
                    .lineLimit(1)
                }
            }
            .padding(
                .vertical,
                3
            )
        }
        .listStyle(
            .plain
        )
        .scrollContentBackground(
            .hidden
        )
        .scrollIndicators(
            .hidden
        )
    }


    // MARK: - Artwork

    @ViewBuilder
    private func artwork(
        _ artwork: Artwork?,
        cornerRadius: CGFloat
    ) -> some View {

        if let artwork {

            ArtworkImage(
                artwork,
                width: 180,
                height: 180
            )
            .aspectRatio(
                1,
                contentMode: .fill
            )
            .frame(
                maxWidth: .infinity
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        cornerRadius,
                    style:
                        .continuous
                )
            )

        } else {

            RoundedRectangle(
                cornerRadius:
                    cornerRadius,
                style:
                    .continuous
            )
            .fill(
                .quaternary
            )
            .aspectRatio(
                1,
                contentMode: .fit
            )
            .overlay {

                Image(
                    systemName:
                        "music.note"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    @ViewBuilder
    private func songArtwork(
        _ artwork: Artwork?
    ) -> some View {

        if let artwork {

            ArtworkImage(
                artwork,
                width: 42,
                height: 42
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 5,
                    style: .continuous
                )
            )

        } else {

            RoundedRectangle(
                cornerRadius: 5,
                style: .continuous
            )
            .fill(.quaternary)
            .frame(
                width: 42,
                height: 42
            )
            .overlay {

                Image(
                    systemName:
                        "music.note"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }
}


#Preview {
    MusicLibraryView(
        store:
            MSRUPreviewData.makeAppleMusicStore()
    )
    .frame(
        width: 1000,
        height: 700
    )
}
