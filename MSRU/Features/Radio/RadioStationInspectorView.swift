//
//  RadioStationInspectorView.swift
//  MSRU
//

import SwiftUI
import Observation

struct RadioStationInspectorView: View {

    let station: RadioStation
    @Bindable var playback: PlaybackController
    var onClose: (() -> Void)? = nil

    private var isCurrent: Bool {
        playback.currentItem?.radioStation?.id == station.id
    }

    private var isPlaying: Bool {
        isCurrent && playback.isPlaying
    }

    private var isResolving: Bool {
        isCurrent && playback.isResolving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Artwork
                VStack(alignment: .center, spacing: 14) {
                    artwork
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isPlaying ? Color.red : Color.secondary)
                                .frame(width: 7, height: 7)
                            Text(isPlaying ? "LIVE BROADCAST" : "INTERNET RADIO")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(isPlaying ? Color.red : Color.secondary)
                        }

                        Text(station.name)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Text(station.genre.rawValue + " • " + station.country)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                // Action Section
                actionsSection

                Divider()

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Station")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(station.description)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Properties Section
                propertiesSection

                Divider()

                // Broadcast & Links Section
                broadcastSection
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    playback.toggle(radio: station)
                } label: {
                    HStack {
                        if isResolving {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Label(
                            isPlaying ? "Pause Stream" : "Tune In",
                            systemImage: isPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 10) {
                Button {
                    playback.playNext(radio: station)
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    playback.addToQueue(radio: station)
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Properties Section

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Broadcast Details")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "Genre", value: station.genre.rawValue)
            propertyRow(label: "Location", value: station.country)
            propertyRow(label: "Language", value: station.language)
            propertyRow(label: "Codec", value: station.codec)
            if let bitrate = station.bitrateKbps {
                propertyRow(label: "Bitrate", value: "\(bitrate) kbps")
            }
        }
    }

    // MARK: - Broadcast & Links Section

    private var broadcastSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stream & Web")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Stream URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(station.streamURL.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            if let homepage = station.homepageURL {
                Link(destination: homepage) {
                    Label("Visit Official Website", systemImage: "safari")
                        .font(.callout)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: station.genre.systemImage)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helper

    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }
}

// MARK: - Preview

#Preview("Radio Station Inspector") {
    let application = MSRUPreviewData.makeApplication()
    let station = RadioStation.defaultStations[0]
    return RadioStationInspectorView(
        station: station,
        playback: application.playback,
        onClose: {}
    )
    .frame(width: 320, height: 620)
}
