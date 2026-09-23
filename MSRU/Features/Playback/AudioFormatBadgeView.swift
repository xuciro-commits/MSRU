//
//  AudioFormatBadgeView.swift
//  MSRU
//

import SwiftUI
import MusicPlayback

struct AudioFormatBadgeView: View {
    let info: AudioFormatInfo?
    var style: Style = .compact

    enum Style {
        case compact
        case prominent
    }

    var body: some View {
        if let info {
            switch style {
            case .compact:
                compactBadge(info)
            case .prominent:
                prominentBadge(info)
            }
        }
    }

    // MARK: - Compact Style (For MiniPlayerBar)

    @ViewBuilder
    private func compactBadge(_ info: AudioFormatInfo) -> some View {
        HStack(spacing: 4) {
            if info.isLossless {
                Image(systemName: "sparkles")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(info.isHiRes ? Color.yellow : Color.accentColor)
            }

            Text(info.codec)
                .font(.system(size: 9, weight: .bold, design: .monospaced))

            if let sampleRate = info.sampleRate {
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(sampleRate)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(
                    info.isHiRes
                        ? Color.yellow.opacity(0.12)
                        : (info.isLossless ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06))
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    info.isHiRes
                        ? Color.yellow.opacity(0.3)
                        : (info.isLossless ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.1)),
                    lineWidth: 0.8
                )
        )
    }

    // MARK: - Prominent Style (For NowPlayingCanvas & ContextPane)

    @ViewBuilder
    private func prominentBadge(_ info: AudioFormatInfo) -> some View {
        HStack(spacing: 8) {
            if info.isLossless {
                HStack(spacing: 3) {
                    Image(systemName: info.isHiRes ? "sparkles" : "waveform.badge.magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                    Text(info.isHiRes ? LocalizedStringKey("HI-RES LOSSLESS") : LocalizedStringKey("LOSSLESS"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(info.isHiRes ? Color.yellow.opacity(0.18) : Color.accentColor.opacity(0.16))
                )
                .foregroundStyle(info.isHiRes ? Color.yellow : Color.accentColor)
            }

            Text(info.codec)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )

            if let bitDepth = info.bitDepth {
                Text(bitDepth)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let sampleRate = info.sampleRate {
                Text(sampleRate)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let bitrate = info.bitrate {
                Text(bitrate)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
        )
    }
}

#Preview("AudioFormatBadgeView - Styles") {
    VStack(spacing: 16) {
        AudioFormatBadgeView(
            info: AudioFormatInfo(
                codec: "FLAC",
                sampleRate: "96.0 kHz",
                bitDepth: "24-bit",
                bitrate: "710 kbps",
                isLossless: true,
                isHiRes: true
            ),
            style: .compact
        )

        AudioFormatBadgeView(
            info: AudioFormatInfo(
                codec: "FLAC",
                sampleRate: "96.0 kHz",
                bitDepth: "24-bit",
                bitrate: "710 kbps",
                isLossless: true,
                isHiRes: true
            ),
            style: .prominent
        )

        AudioFormatBadgeView(
            info: AudioFormatInfo(
                codec: "AAC",
                sampleRate: "44.1 kHz",
                bitDepth: nil,
                bitrate: "128 kbps",
                isLossless: false,
                isHiRes: false
            ),
            style: .compact
        )

        AudioFormatBadgeView(
            info: AudioFormatInfo(
                codec: "AAC",
                sampleRate: "44.1 kHz",
                bitDepth: nil,
                bitrate: "128 kbps",
                isLossless: false,
                isHiRes: false
            ),
            style: .prominent
        )
    }
    .padding()
}
