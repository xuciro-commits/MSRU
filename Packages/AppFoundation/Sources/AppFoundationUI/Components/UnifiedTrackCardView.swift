//
//  UnifiedTrackCardView.swift
//  AppFoundationUI
//

import SwiftUI
import AppFoundation

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

// MARK: - Preview

#Preview("Unified Track Card · Normal & Selected") {
    HStack(spacing: 20) {
        UnifiedTrackCardView(
            title: "晴天",
            subtitle: "周杰伦",
            secondaryText: "叶惠美",
            durationText: "04:29",
            qualityBadge: "LOSSLESS",
            isPlaying: false,
            isSelected: false,
            onSelect: {},
            onPlay: {}
        ) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
        }

        UnifiedTrackCardView(
            title: "七里香",
            subtitle: "周杰伦",
            secondaryText: "七里香",
            durationText: "04:59",
            qualityBadge: "HI-RES",
            isPlaying: true,
            isSelected: true,
            onSelect: {},
            onPlay: {}
        ) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.2))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                }
        } actionsMenu: {
            Menu {
                Button("Add to Queue") {}
                Button("Show in Finder") {}
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 22, height: 18)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
    .padding(24)
    .frame(width: 440)
}
