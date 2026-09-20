//
//  RadioStationCardView.swift
//  MSRU
//

import SwiftUI
import AppFoundation

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
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // Artwork / Poster area
                ZStack(alignment: .topTrailing) {
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

                    // Big background genre icon
                    Image(systemName: station.genre.systemImage)
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    // Top Left Badges: Custom tag
                    HStack {
                        if station.isCustom {
                            Text("CUSTOM")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.75))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Top Right Controls: Favorite & LIVE pill
                    HStack(spacing: 6) {
                        Button {
                            onToggleFavorite?()
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isFavorite ? Color.red : Color.white.opacity(0.85))
                                .padding(5)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                        // Live Pill Badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isPlaying ? Color.red : Color.white.opacity(0.8))
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.5)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                    }
                    .padding(8)

                    // Overlay Play/Pause Button
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                        if isResolving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .opacity(isHovered || isPlaying || isResolving ? 1 : 0.85)
                    .onTapGesture {
                        onPlayPause()
                    }
                }
                .frame(height: 140)

                // Info Area
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(station.description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(height: 28, alignment: .topLeading)

                    HStack(spacing: 6) {
                        Text(station.genre.rawValue)
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
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isHovered)
            .animation(.easeOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
