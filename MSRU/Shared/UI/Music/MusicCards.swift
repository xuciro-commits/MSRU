//
//  MusicCards.swift
//  MSRU
//
//  Music-specific cards built on the generic AppFoundationUI FoundationCard.
//  Moved out of AppFoundationUI in #75: album, artist and track vocabulary
//  belongs to the Music product, not the Apple client layer.
//

import SwiftUI
import AppFoundationUI
import MusicDomain

#Preview("Music Cards") {
    HStack(alignment: .top, spacing: 20) {
        AlbumCardView(
            album: AlbumPresentationModel(id: "preview-album", title: "Preview Album", artist: "Preview Artist", trackCount: 10, duration: 1800),
            onSelect: {}
        ) {
            Image(systemName: "music.note.list")
                .frame(width: 140, height: 140)
        }
        ArtistAvatarView(
            artist: ArtistPresentationModel(id: "preview-artist", name: "Preview Artist", albumCount: 1, trackCount: 10),
            onSelect: {}
        ) {
            Image(systemName: "person.crop.circle")
                .frame(width: 140, height: 140)
        }
        UnifiedTrackCardView(title: "Preview Track", subtitle: "Preview Artist", onSelect: {}, onPlay: {}) {
            Image(systemName: "music.note")
                .frame(width: 140, height: 140)
        }
    }
    .padding()
}

// MARK: - Album Card View

public struct AlbumCardView<Cover: View>: View {
    public let album: AlbumPresentationModel
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onPlay: () -> Void
    private let customCover: Cover?

    public init(
        album: AlbumPresentationModel,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onPlay: @escaping () -> Void = {},
        @ViewBuilder cover: () -> Cover
    ) {
        self.album = album
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onPlay = onPlay
        self.customCover = cover()
    }

    public var body: some View {
        FoundationCard(
            titleText: album.title,
            subtitleText: album.artist,
            footerText: album.year != nil ? String(album.year!) : nil,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            if let customCover {
                customCover
            } else {
                coverImageView
            }
        } topTrailingBadges: {
            if let badge = album.audioQualityBadge {
                FoundationCardBadge(badge)
            }
        } actionOverlay: {
            FoundationCardActionButton(systemImage: "play.fill", action: onPlay)
        }
    }

    @ViewBuilder
    private var coverImageView: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .aspectRatio(1.0, contentMode: .fit)
            .overlay {
                if let data = album.artworkData, let image = Image(foundationArtworkData: data) {
                    image
                        .resizable()
                        .scaledToFill()
                } else if let url = album.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderNoteView
                        @unknown default:
                            placeholderNoteView
                        }
                    }
                } else {
                    placeholderNoteView
                }
            }
            .clipped()
    }

    private var placeholderNoteView: some View {
        Image(systemName: "music.note")
            .font(.system(size: 40))
            .foregroundStyle(.secondary.opacity(0.5))
    }
}

extension AlbumCardView where Cover == EmptyView {
    public init(
        album: AlbumPresentationModel,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onPlay: @escaping () -> Void = {}
    ) {
        self.album = album
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onPlay = onPlay
        self.customCover = nil
    }
}

// MARK: - Artist Avatar View

public struct ArtistAvatarView<Avatar: View>: View {
    public let artist: ArtistPresentationModel
    public let isSelected: Bool
    public let onSelect: () -> Void
    private let customAvatar: Avatar?

    @State private var isHovered: Bool = false

    public init(
        artist: ArtistPresentationModel,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        @ViewBuilder avatar: () -> Avatar
    ) {
        self.artist = artist
        self.isSelected = isSelected
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
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.16), value: isHovered)

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
        .padding(8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var avatarImageView: some View {
        Circle()
            .fill(Color.secondary.opacity(0.15))
            .aspectRatio(1.0, contentMode: .fit)
            .overlay {
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
            .clipped()
    }

    private var placeholderAvatarView: some View {
        Image(systemName: "music.mic")
            .font(.system(size: 40))
            .foregroundStyle(.secondary.opacity(0.5))
    }
}

extension ArtistAvatarView where Avatar == EmptyView {
    public init(
        artist: ArtistPresentationModel,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.artist = artist
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.customAvatar = nil
    }
}

// MARK: - Unified Track Card View

public struct UnifiedTrackCardView<Artwork: View, ActionsMenu: View>: View {
    public let title: String
    public let subtitle: String
    public let secondaryText: String?
    public let durationText: String?
    public let qualityBadge: String?
    public let isPlaying: Bool
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onPlay: () -> Void
    public let artwork: Artwork
    public let actionsMenu: ActionsMenu?

    public init(
        title: String,
        subtitle: String,
        secondaryText: String? = nil,
        durationText: String? = nil,
        qualityBadge: String? = nil,
        isPlaying: Bool = false,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder actionsMenu: () -> ActionsMenu
    ) {
        self.title = title
        self.subtitle = subtitle
        self.secondaryText = secondaryText
        self.durationText = durationText
        self.qualityBadge = qualityBadge
        self.isPlaying = isPlaying
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onPlay = onPlay
        self.artwork = artwork()
        self.actionsMenu = actionsMenu()
    }

    public init(
        title: String,
        subtitle: String,
        secondaryText: String? = nil,
        durationText: String? = nil,
        qualityBadge: String? = nil,
        isPlaying: Bool = false,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        @ViewBuilder artwork: () -> Artwork
    ) where ActionsMenu == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.secondaryText = secondaryText
        self.durationText = durationText
        self.qualityBadge = qualityBadge
        self.isPlaying = isPlaying
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onPlay = onPlay
        self.artwork = artwork()
        self.actionsMenu = nil
    }

    public var body: some View {
        FoundationCard(
            aspectRatio: 1.0,
            cornerRadius: 10,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            artwork
        } topLeadingBadges: {
            if let qualityBadge {
                FoundationCardBadge(qualityBadge)
            }
        } actionOverlay: {
            FoundationCardActionButton(
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                action: onPlay
            )
        } title: {
            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        } subtitle: {
            Text(subtitle)
                .font(.caption)
                .lineLimit(1)
        } footer: {
            HStack(spacing: 6) {
                if let secondaryText {
                    Text(secondaryText)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                if let durationText {
                    Text(durationText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                if let actionsMenu {
                    actionsMenu
                }
            }
        }
    }
}
