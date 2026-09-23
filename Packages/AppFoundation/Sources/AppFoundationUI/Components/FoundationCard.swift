//
//  FoundationCard.swift
//  AppFoundationUI
//
//  Created for the Application Foundation Framework.
//

import SwiftUI
import AppFoundation

#Preview("Foundation Cards") {
    HStack(alignment: .top, spacing: 20) {
        VStack(spacing: 12) {
            FoundationCardBadge("NEW", systemImage: "sparkles")
            FoundationCardActionButton(title: "Open", action: {})
            FoundationCard(titleText: "Preview Item", subtitleText: "Preview Subtitle", onSelect: {}) {
                Image(systemName: "music.note")
                    .frame(width: 140, height: 140)
            }
        }
    }
    .padding()
}

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
