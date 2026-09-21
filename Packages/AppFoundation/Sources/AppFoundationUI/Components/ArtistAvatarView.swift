//
//  ArtistAvatarView.swift
//  AppFoundationUI
//

import SwiftUI
import AppFoundation

public struct ArtistAvatarView<Avatar: View>: View {
    public let artist: ArtistPresentationModel
    public let onSelect: () -> Void
    private let customAvatar: Avatar?

    @State private var isHovered: Bool = false

    public init(
        artist: ArtistPresentationModel,
        onSelect: @escaping () -> Void,
        @ViewBuilder avatar: () -> Avatar
    ) {
        self.artist = artist
        self.onSelect = onSelect
        self.customAvatar = avatar()
    }

    public var body: some View {
        VStack(spacing: 10) {
            Group {
                if let customAvatar {
                    customAvatar
                } else {
                    avatarImageView
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(Circle())
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 12 : 5, y: isHovered ? 6 : 2)
            .scaleEffect(isHovered ? 1.03 : 1.0)

            VStack(spacing: 2) {
                Text(artist.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(artist.displaySubtitle)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var avatarImageView: some View {
        if let data = artist.artworkData, let image = Image(foundationArtworkData: data) {
            image
                .resizable()
                .scaledToFill()
        } else if let url = artist.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderAvatarView
                @unknown default:
                    placeholderAvatarView
                }
            }
        } else {
            placeholderAvatarView
        }
    }

    private var placeholderAvatarView: some View {
        Circle()
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
    }
}

extension ArtistAvatarView where Avatar == EmptyView {
    public init(
        artist: ArtistPresentationModel,
        onSelect: @escaping () -> Void
    ) {
        self.artist = artist
        self.onSelect = onSelect
        self.customAvatar = nil
    }
}

// MARK: - Preview

#Preview("Artist Avatar View") {
    ArtistAvatarView(
        artist: ArtistPresentationModel(
            id: "preview-artist",
            name: "周杰伦",
            aliases: ["Jay Chou", "周董"],
            country: "TW",
            albumCount: 15,
            trackCount: 180
        ),
        onSelect: {}
    )
    .frame(width: 160)
    .padding()
}
