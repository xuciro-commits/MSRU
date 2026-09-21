//
//  MusicComponents.swift
//  MSRU
//

import SwiftUI
import AppFoundationUI

// MARK: - Music Artwork View

struct MusicArtworkView: View {
    let url: URL?
    var aspectRatio: CGFloat = 1
    var cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            artwork
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private var artwork: some View {
        if let url {
            AsyncImage(
                url: url,
                transaction: Transaction(animation: .easeOut(duration: 0.2))
            ) { phase in
                switch phase {
                case .empty:
                    placeholder
                        .overlay {
                            ProgressView().controlSize(.small)
                        }
                case .success(let image):
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

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Music Card View

enum MusicCardStyle {
    case featured
    case standard
    case compact
}

struct MusicCardView: View {
    let item: MusicContent
    let style: MusicCardStyle

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

    private var featuredCard: some View {
        ZStack(alignment: .bottomLeading) {
            MusicArtworkView(
                url: item.artworkURL,
                aspectRatio: 16 / 10,
                cornerRadius: 16
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("FEATURED ALBUM")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(item.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }
            }
            .padding(18)
        }
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            MusicArtworkView(url: item.artworkURL, cornerRadius: 10)

            Text(item.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 180, alignment: .topLeading)
    }

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            MusicArtworkView(url: item.artworkURL, cornerRadius: 8)

            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 140, alignment: .topLeading)
    }
}

// MARK: - Music Section View

struct MusicSectionView: View {
    let section: MusicSection
    let onSelect: (MusicContent) -> Void

    @Environment(\.workspaceSafeAreaInsets)
    private var workspaceSafeArea

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(section.title)
                .font(.title2.bold())

            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, workspaceSafeArea.trailing + 28)
    }

    @ViewBuilder
    private var content: some View {
        switch section.layout {
        case .featured:
            horizontalShelf(style: .featured, spacing: 18)
        case .shelf:
            horizontalShelf(style: .standard, spacing: 16)
        case .compactShelf:
            horizontalShelf(style: .compact, spacing: 14)
        case .grid:
            grid
        }
    }

    private func horizontalShelf(style: MusicCardStyle, spacing: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: spacing) {
                ForEach(section.items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        MusicCardView(item: item, style: style)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 28)
            .padding(.trailing, workspaceSafeArea.trailing + 28)
        }
        .scrollIndicators(.hidden)
        .hideScrollIndicatorsCompletely()
        .ignoresSafeArea(.all, edges: .trailing)
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 18)],
            alignment: .leading,
            spacing: 24
        ) {
            ForEach(section.items) { item in
                Button {
                    onSelect(item)
                } label: {
                    MusicCardView(item: item, style: .standard)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, workspaceSafeArea.trailing + 28)
    }
}
