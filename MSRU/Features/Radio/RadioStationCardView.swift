//
//  RadioStationCardView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI

struct RadioStationCardView: View {

    let station: RadioStation
    let isSelected: Bool
    let isCurrent: Bool
    let playbackState: TrackPlaybackState
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let onPlayPause: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    private var isPlaying: Bool {
        isCurrent && playbackState.isPlaying
    }

    private var isResolving: Bool {
        isCurrent && playbackState.isResolving
    }

    var body: some View {
        FoundationCard(
            aspectRatio: 16.0 / 11.0,
            cornerRadius: 12,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            // Media Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: cardGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )

                Image(systemName: station.genre.systemImage)
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.18))
            }
        } topLeadingBadges: {
            if station.isCustom {
                FoundationCardBadge("Custom", foregroundStyle: .white, backgroundStyle: Color.blue.opacity(0.85))
            }
        } topTrailingBadges: {
            HStack(spacing: 6) {
                Button {
                    onToggleFavorite?()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.red : Color.white.opacity(0.85))
                        .padding(5)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                FoundationCardBadge(
                    "Live",
                    systemImage: "circle.fill",
                    foregroundStyle: .white,
                    backgroundStyle: isPlaying ? Color.red : Color.black.opacity(0.45)
                )
            }
        } actionOverlay: {
            if isResolving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.ultraThinMaterial))
            } else {
                FoundationCardActionButton(
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    action: onPlayPause
                )
            }
        } title: {
            Text(station.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        } subtitle: {
            Text(station.description)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 28, alignment: .topLeading)
        } footer: {
            HStack(spacing: 6) {
                Text(LocalizedStringKey(station.genre.rawValue))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())

                Spacer()

                Text(station.country)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button(isPlaying ? "Pause" : "Play") {
                onPlayPause()
            }
            Button(isFavorite ? "Remove from Favorites" : "Favorite") {
                onToggleFavorite?()
            }
            if station.isCustom, let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Custom Station", systemImage: "trash")
                }
            }
        }
    }

    private var cardGradientColors: [Color] {
        switch station.genre {
        case .indie:
            return [Color(red: 0.16, green: 0.38, blue: 0.48), Color(red: 0.09, green: 0.20, blue: 0.28)]
        case .electronic:
            return [Color(red: 0.40, green: 0.15, blue: 0.52), Color(red: 0.15, green: 0.08, blue: 0.35)]
        case .classical:
            return [Color(red: 0.52, green: 0.30, blue: 0.14), Color(red: 0.26, green: 0.14, blue: 0.07)]
        case .jazz:
            return [Color(red: 0.20, green: 0.36, blue: 0.30), Color(red: 0.09, green: 0.18, blue: 0.15)]
        case .pop:
            return [Color(red: 0.56, green: 0.18, blue: 0.35), Color(red: 0.30, green: 0.09, blue: 0.20)]
        case .ambient:
            return [Color(red: 0.15, green: 0.25, blue: 0.42), Color(red: 0.06, green: 0.12, blue: 0.22)]
        case .all:
            return [Color(red: 0.25, green: 0.27, blue: 0.38), Color(red: 0.12, green: 0.13, blue: 0.20)]
        }
    }
}

#Preview("Radio Station Card") {
    let station = RadioStation.defaultStations[1]
    return RadioStationCardView(
        station: station,
        isSelected: true,
        isCurrent: true,
        playbackState: .playing,
        isFavorite: true,
        onToggleFavorite: {},
        onPlayPause: {},
        onSelect: {}
    )
    .frame(width: 220)
    .padding(20)
}
