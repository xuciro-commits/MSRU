//
//  TrackInspectorView.swift
//  MSRU
//

import SwiftUI
import Observation

struct TrackInspectorView: View {

    let localTrack: LocalTrack?
    let musicContent: MusicContent?

    @Bindable var playback: PlaybackController
    @Bindable var library: LibraryStore

    var onRevealInFinder: ((URL) -> Void)? = nil
    var onClose: (() -> Void)? = nil

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
    }

    // MARK: - Local Track Content

    private func localTrackContent(_ track: LocalTrack) -> some View {
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

                let isSaved = library.contains(local: track)
                Button {
                    Task {
                        if isSaved {
                            await library.remove(local: track)
                        } else {
                            await library.add(local: track)
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(isSaved ? Color.red : Color.primary)
                }
                .buttonStyle(.bordered)
                .help(isSaved ? "Remove from Library" : "Add to Library")
            }

            HStack(spacing: 10) {
                Button {
                    playback.playNext(track)
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    playback.addToQueue(track)
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

            propertyRow(label: "Kind", value: "Local Audio File")

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
                    Label("Show in Finder", systemImage: "arrow.up.forward.square")
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
                    AsyncImage(url: content.artworkURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            placeholderArtwork
                        }
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    propertyRow(label: "Provider", value: content.provider.title)
                    propertyRow(label: "Type", value: content.kind.rawValue.capitalized)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Empty State

    private var emptySelectionView: some View {
        ContentUnavailableView {
            Label("No Track Selected", systemImage: "music.note")
        } description: {
            Text("Select a track from your library or browse to view its properties and audio details.")
        }
    }

    // MARK: - Row Helper

    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    // MARK: - Artwork Helpers

    @ViewBuilder
    private func artwork(_ track: LocalTrack) -> some View {
        if let data = track.artworkData, let image = Image(artworkData: data) {
            image
                .resizable()
                .scaledToFill()
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
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
        library: application.library,
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
        library: application.library,
        onRevealInFinder: { _ in },
        onClose: {}
    )
    .frame(width: 320, height: 600)
}
