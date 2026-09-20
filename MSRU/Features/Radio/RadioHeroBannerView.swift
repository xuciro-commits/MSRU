//
//  RadioHeroBannerView.swift
//  MSRU
//

import SwiftUI
import AppFoundation

struct RadioHeroBannerView: View {

    let station: RadioStation
    let isPlaying: Bool
    let isCurrent: Bool
    let onPlayPause: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                // Background artistic gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: bannerColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )

                // Background subtle decorative pattern
                HStack {
                    Spacer()
                    Image(systemName: station.genre.systemImage)
                        .font(.system(size: 140, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.12))
                        .offset(x: 20, y: 10)
                }
                .clipped()

                // Content
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        // LIVE Badge
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isCurrent && isPlaying ? Color.red : Color.white)
                                .frame(width: 7, height: 7)
                            Text("Featured Live")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                        Text(LocalizedStringKey(station.genre.rawValue))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.2))
                            .clipShape(Capsule())

                        Spacer()

                        if let bitrate = station.bitrateKbps {
                            Text("\(bitrate) kbps • \(station.codec)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(station.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(station.description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 12) {
                        Button(action: onPlayPause) {
                            HStack(spacing: 8) {
                                Image(systemName: isCurrent && isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(LocalizedStringKey(isCurrent && isPlaying ? "Pause Stream" : "Listen Now"))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)

                        Text("\(station.country) • \(station.language)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(22)
            }
            .frame(height: 190)
            .shadow(color: .black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            .scaleEffect(isHovered ? 1.008 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var bannerColors: [Color] {
        switch station.genre {
        case .indie:
            return [Color(red: 0.15, green: 0.35, blue: 0.45), Color(red: 0.08, green: 0.18, blue: 0.28)]
        case .electronic:
            return [Color(red: 0.35, green: 0.12, blue: 0.48), Color(red: 0.12, green: 0.08, blue: 0.32)]
        case .classical:
            return [Color(red: 0.48, green: 0.28, blue: 0.12), Color(red: 0.24, green: 0.12, blue: 0.06)]
        case .jazz:
            return [Color(red: 0.18, green: 0.32, blue: 0.28), Color(red: 0.08, green: 0.16, blue: 0.14)]
        case .pop:
            return [Color(red: 0.52, green: 0.15, blue: 0.32), Color(red: 0.28, green: 0.08, blue: 0.18)]
        case .ambient:
            return [Color(red: 0.12, green: 0.22, blue: 0.38), Color(red: 0.05, green: 0.10, blue: 0.20)]
        case .all:
            return [Color(red: 0.22, green: 0.24, blue: 0.35), Color(red: 0.10, green: 0.11, blue: 0.18)]
        }
    }
}

#Preview("Radio Hero Banner") {
    let station = RadioStation.defaultStations[0]
    return RadioHeroBannerView(
        station: station,
        isPlaying: true,
        isCurrent: true,
        onPlayPause: {},
        onSelect: {}
    )
    .padding(28)
    .frame(width: 680)
}
