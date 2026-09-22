//
//  FoundationCard.swift
//  AppFoundationUI
//
//  Created for the Application Foundation Framework.
//

import SwiftUI
import AppFoundation

// MARK: - Foundation Card Badge

public struct FoundationCardBadge: View {
    public let text: String
    public let systemImage: String?
    public let foregroundStyle: AnyShapeStyle
    public let backgroundStyle: AnyShapeStyle

    public init(
        _ text: String,
        systemImage: String? = nil,
        foregroundStyle: some ShapeStyle = .primary,
        backgroundStyle: some ShapeStyle = .ultraThinMaterial
    ) {
        self.text = text
        self.systemImage = systemImage
        self.foregroundStyle = AnyShapeStyle(foregroundStyle)
        self.backgroundStyle = AnyShapeStyle(backgroundStyle)
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.3)
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(backgroundStyle, in: Capsule())
    }
}

// MARK: - Foundation Card Action Button

public struct FoundationCardActionButton: View {
    public let systemImage: String
    public let title: String?
    public let action: () -> Void

    public init(
        systemImage: String = "play.fill",
        title: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: title == nil ? 38 : nil, height: 38)
            .padding(.horizontal, title == nil ? 0 : 12)
            .background(Circle().fill(Color.accentColor))
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Foundation Card

public struct FoundationCard<
    Media: View,
    TopLeadingBadges: View,
    TopTrailingBadges: View,
    ActionOverlay: View,
    Title: View,
    Subtitle: View,
    Footer: View
>: View {

    public let aspectRatio: CGFloat
    public let cornerRadius: CGFloat
    public let isSelected: Bool
    public let onSelect: () -> Void

    @ViewBuilder public let media: Media
    @ViewBuilder public let topLeadingBadges: TopLeadingBadges
    @ViewBuilder public let topTrailingBadges: TopTrailingBadges
    @ViewBuilder public let actionOverlay: ActionOverlay
    @ViewBuilder public let title: Title
    @ViewBuilder public let subtitle: Subtitle
    @ViewBuilder public let footer: Footer

    @State private var isHovered: Bool = false

    public init(
        aspectRatio: CGFloat = 1.0,
        cornerRadius: CGFloat = 10.0,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        @ViewBuilder media: () -> Media,
        @ViewBuilder topLeadingBadges: () -> TopLeadingBadges = { EmptyView() },
        @ViewBuilder topTrailingBadges: () -> TopTrailingBadges = { EmptyView() },
        @ViewBuilder actionOverlay: () -> ActionOverlay = { EmptyView() },
        @ViewBuilder title: () -> Title,
        @ViewBuilder subtitle: () -> Subtitle = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.media = media()
        self.topLeadingBadges = topLeadingBadges()
        self.topTrailingBadges = topTrailingBadges()
        self.actionOverlay = actionOverlay()
        self.title = title()
        self.subtitle = subtitle()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media Frame with rigid, deterministic aspect-ratio anchor
            media
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(
                    color: isHovered ? .black.opacity(0.16) : .clear,
                    radius: isHovered ? 6 : 0,
                    y: isHovered ? 3 : 0
                )
                .overlay(alignment: .topLeading) {
                    topLeadingBadges
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    topTrailingBadges
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isHovered {
                        actionOverlay
                            .padding(8)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isHovered)

            // Text Stack
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                subtitle
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                footer
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
            }
        }
        .padding(8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
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
}

// MARK: - Convenience Initializer for Standard Text Cards

extension FoundationCard where
    Title == Text,
    Subtitle == Text,
    Footer == Text {

    public init(
        titleText: String,
        subtitleText: String? = nil,
        footerText: String? = nil,
        aspectRatio: CGFloat = 1.0,
        cornerRadius: CGFloat = 10.0,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        @ViewBuilder media: () -> Media,
        @ViewBuilder topLeadingBadges: () -> TopLeadingBadges = { EmptyView() },
        @ViewBuilder topTrailingBadges: () -> TopTrailingBadges = { EmptyView() },
        @ViewBuilder actionOverlay: () -> ActionOverlay = { EmptyView() }
    ) {
        self.init(
            aspectRatio: aspectRatio,
            cornerRadius: cornerRadius,
            isSelected: isSelected,
            onSelect: onSelect,
            media: media,
            topLeadingBadges: topLeadingBadges,
            topTrailingBadges: topTrailingBadges,
            actionOverlay: actionOverlay,
            title: { Text(titleText) },
            subtitle: { Text(subtitleText ?? "") },
            footer: { Text(footerText ?? "") }
        )
    }
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
