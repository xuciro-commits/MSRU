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
            // Media Frame
            ZStack(alignment: .bottomTrailing) {
                media
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(
                        color: .black.opacity(isHovered ? 0.16 : 0.06),
                        radius: isHovered ? 10 : 5,
                        y: isHovered ? 6 : 2
                    )

                // Top Leading Badges
                VStack {
                    HStack {
                        topLeadingBadges
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)

                // Top Trailing Badges
                VStack {
                    HStack {
                        Spacer()
                        topTrailingBadges
                    }
                    Spacer()
                }
                .padding(8)

                // Action Overlay on Hover
                if isHovered {
                    actionOverlay
                        .padding(8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

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
        .background(
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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

// MARK: - Preview

#Preview("FoundationCard Variations") {
    HStack(spacing: 24) {
        // Standard 1:1 Album Style Card
        FoundationCard(
            titleText: "Abbey Road",
            subtitleText: "The Beatles",
            footerText: "1969 • 17 tracks",
            onSelect: {}
        ) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.blue.gradient)
                .overlay {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))
                }
        } topLeadingBadges: {
            FoundationCardBadge("HI-RES", systemImage: "sparkles")
        } actionOverlay: {
            FoundationCardActionButton(systemImage: "play.fill", action: {})
        }

        // 16:9 Video/Station Style Card (Selected)
        FoundationCard(
            titleText: "Chillhop Radio 24/7",
            subtitleText: "Lo-Fi Beats to Study & Relax",
            footerText: "1.2k listeners",
            aspectRatio: 16.0 / 9.0,
            isSelected: true,
            onSelect: {}
        ) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.purple.gradient)
                .overlay {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.8))
                }
        } topTrailingBadges: {
            FoundationCardBadge("LIVE", foregroundStyle: .white, backgroundStyle: Color.red)
        } actionOverlay: {
            FoundationCardActionButton(systemImage: "pause.fill", action: {})
        }
    }
    .padding(32)
    .frame(width: 500)
}
