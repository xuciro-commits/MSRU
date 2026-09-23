//
//  TrackInspectorView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

struct TrackInspectorView: View {

    var localTrack: LocalTrack? = nil
    var musicContent: MusicContent? = nil

    @Bindable var playback: PlaybackController
    var localStore: LocalLibraryStore? = nil

    var onRevealInFinder: ((URL) -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @State private var inspectorTab: InspectorTab = .details
    @State private var isReidentifying: Bool = false
    @State private var reidentifyStatus: String? = nil

    enum InspectorTab: String, CaseIterable, Identifiable {
        case details = "Track Details"
        case identification = "Identification"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let track = localTrack {
                localTrackContent(track)
            } else if let content = musicContent {
                musicContentDetails(content)
            } else {
                emptySelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(Color.accentColor)
    }

    // MARK: - Library Track Content

    private var tabPicker: some View {
        HStack(spacing: 3) {
            ForEach(InspectorTab.allCases) { tab in
                let isSelected = inspectorTab == tab
                Button {
                    inspectorTab = tab
                } label: {
                    Text(LocalizedStringKey(tab.rawValue))
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Local Track Content

    private func localTrackContent(_ track: LocalTrack) -> some View {
        VStack(spacing: 0) {
            tabPicker

            switch inspectorTab {
            case .details:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header & Artwork
                        VStack(alignment: .center, spacing: 14) {
                            artwork(track)
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

                            VStack(spacing: 4) {
                                Text(track.title)
                                    .font(.title3.bold())
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text(track.artist + (track.album.map { " · " + $0 } ?? ""))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        // Action Buttons
                        actionsSection(track)

                        Divider()

                        // Properties
                        propertiesSection(track)

                        Divider()

                        // Source (Read-only)
                        sourceSection(track)
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            case .identification:
                ScrollView {
                    identificationContent(track)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            }
        }
    }

    // MARK: - Identification Panel

    private func identificationContent(_ track: LocalTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fingerprint & External Catalog:")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Button {
                guard !isReidentifying, let localStore else { return }
                isReidentifying = true
                reidentifyStatus = nil
                Task {
                    defer { isReidentifying = false }
                    let success = await localStore.reidentifyTrack(trackID: track.id)
                    reidentifyStatus = success
                        ? String(localized: "Successfully matched and updated artwork!")
                        : String(localized: "No online match found on MusicBrainz.")
                }
            } label: {
                HStack(spacing: 6) {
                    if isReidentifying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Online Re-identification (MusicBrainz)")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(Color.accentColor)
            .controlSize(.small)
            .disabled(isReidentifying || localStore == nil || !track.fileURL.isFileURL)

            if let status = reidentifyStatus {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }

    // MARK: - Actions Section

    private func actionsSection(_ track: LocalTrack) -> some View {
        VStack(spacing: 10) {
            let isCurrent = playback.currentTrack?.id == track.id
            let isPlaying = isCurrent && playback.isPlaying

            HStack(spacing: 10) {
                Button {
                    playback.toggle(track: track, queue: [track])
                } label: {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                }

                VStack(spacing: 8) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Properties Section

    private func propertiesSection(_ track: LocalTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Properties")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "Title", value: track.title)
            propertyRow(label: "Artist", value: track.artist)
            if let album = track.album {
                propertyRow(label: "Album", value: album)
            }
            propertyRow(label: "Duration", value: durationString(track.duration))
            propertyRow(label: "Format", value: track.fileURL.pathExtension.uppercased())
            if let fileSize = fileSizeString(for: track.fileURL) {
                propertyRow(label: "Size", value: fileSize)
            }
        }
    }

    // MARK: - Source Section

    private func sourceSection(_ track: LocalTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source (Read-only)")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "Genre", value: "Local Audio File")

            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(track.fileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            if let onRevealInFinder {
                Button {
                    onRevealInFinder(track.fileURL)
                } label: {
                    Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Music Content (Remote / Catalog)

    private func musicContentDetails(_ content: MusicContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .center, spacing: 14) {
                    MediaImageView(
                        url: content.artworkURL,
                        fixedSize: CGSize(width: 160, height: 160),
                        thumbnailPixelSize: CGSize(width: 320, height: 320),
                        cornerRadius: 14
                    )
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

                    VStack(spacing: 4) {
                        Text(content.title)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        if let subtitle = content.subtitle {
                            Text(subtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    propertyRow(label: "Title", value: content.title)
                    if let subtitle = content.subtitle {
                        propertyRow(label: "Subtitle", value: subtitle)
                    }
                    propertyRow(label: "Providers", value: content.provider.title)
                    propertyRow(label: "Genre", value: content.kind.rawValue.capitalized)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hideScrollIndicatorsCompletely()
    }

    // MARK: - Empty State

    private var emptySelectionView: some View {
        ContentUnavailableView {
            Label("No Track Selected", systemImage: "music.note")
        } description: {
            Text("Select a track from Library or Browse to view properties and audio details.")
        }
    }

    // MARK: - Row Helper

    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(LocalizedStringKey(label))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(LocalizedStringKey(value))
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func artwork(_ track: LocalTrack) -> some View {
        MediaImageView(
            reference: track.artworkReference,
            thumbnailPixelSize: CGSize(width: 320, height: 320),
            placeholderSystemImage: "music.note",
            cornerRadius: 14
        )
    }

    // MARK: - Formatters

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func fileSizeString(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Preview

#Preview("Track Inspector · Populated") {
    let application = MSRUPreviewData.makeApplication()
    TrackInspectorView(
        localTrack: MSRUPreviewData.localTracks[0],
        musicContent: nil,
        playback: application.playback,
        onRevealInFinder: { _ in },
        onClose: {}
    )
    .frame(width: 320, height: 600)
}

#Preview("Track Inspector · Empty") {
    let application = MSRUPreviewData.makeApplication()
    TrackInspectorView(
        localTrack: nil,
        musicContent: nil,
        playback: application.playback,
        onRevealInFinder: { _ in },
        onClose: {}
    )
    .frame(width: 320, height: 600)
}
