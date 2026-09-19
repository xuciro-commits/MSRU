//
//  LocalTrackTableView.swift
//  MSRU
//

import SwiftUI
import Observation

struct LocalTrackTableView: View {

    let tracks: [LocalTrack]
    @Binding var selectedTrack: LocalTrack?
    @Bindable var playback: PlaybackController
    @Bindable var library: LibraryStore

    var onRevealInFinder: ((URL) -> Void)? = nil

    @State private var selectedTrackID: String?

    var body: some View {
        Table(tracks, selection: $selectedTrackID) {
            // Playing indicator / Index column
            TableColumn("#") { track in
                let isCurrent = isCurrentTrack(track)
                HStack(spacing: 4) {
                    if isCurrent && playback.isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.caption)
                    } else if isCurrent {
                        Image(systemName: "pause.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.caption2)
                    } else if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 32, alignment: .center)
            }
            .width(min: 32, ideal: 36, max: 44)

            // Title column (Artwork + Title)
            TableColumn("Title") { track in
                HStack(spacing: 10) {
                    trackArtwork(track)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundStyle(isCurrentTrack(track) ? Color.accentColor : Color.primary)
                    }
                }
                .contextMenu {
                    trackContextMenu(track)
                }
            }
            .width(min: 180, ideal: 240)

            // Artist column
            TableColumn("Artist") { track in
                Text(track.artist)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160)

            // Album column
            TableColumn("Album") { track in
                Text(track.album ?? "—")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160)

            // Duration column
            TableColumn("Time") { track in
                Text(durationString(track.duration))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 60, max: 70)

            // Favorite column
            TableColumn("Favorite") { track in
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
                        .foregroundStyle(isSaved ? Color.red : Color.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help(isSaved ? "Remove from Library" : "Add to Library")
            }
            .width(min: 32, ideal: 36, max: 40)
        }
        .onChange(of: selectedTrackID) { _, newID in
            if let newID, let found = tracks.first(where: { $0.id == newID }) {
                if selectedTrack?.id != found.id {
                    selectedTrack = found
                }
            } else if newID == nil {
                selectedTrack = nil
            }
        }
        .onChange(of: selectedTrack?.id) { _, newSelectedID in
            if selectedTrackID != newSelectedID {
                selectedTrackID = newSelectedID
            }
        }
        .onAppear {
            selectedTrackID = selectedTrack?.id
        }
    }

    // MARK: - Helpers

    private func isCurrentTrack(_ track: LocalTrack) -> Bool {
        playback.currentTrack?.id == track.id
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    @ViewBuilder
    private func trackArtwork(_ track: LocalTrack) -> some View {
        if let data = track.artworkData, let image = Image(artworkData: data) {
            image.resizable().scaledToFill()
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.note")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private func trackContextMenu(_ track: LocalTrack) -> some View {
        Button {
            playback.toggle(track: track, queue: tracks)
        } label: {
            Label(isCurrentTrack(track) && playback.isPlaying ? "Pause" : "Play",
                  systemImage: isCurrentTrack(track) && playback.isPlaying ? "pause.fill" : "play.fill")
        }

        Button {
            playback.playNext(track)
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }

        Button {
            playback.addToQueue(track)
        } label: {
            Label("Add to Queue", systemImage: "text.badge.plus")
        }

        Divider()

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
            Label(isSaved ? "Remove from Library" : "Add to Library",
                  systemImage: isSaved ? "heart.slash" : "heart")
        }

        if let onRevealInFinder {
            Button {
                onRevealInFinder(track.fileURL)
            } label: {
                Label("Show in Finder", systemImage: "arrow.up.forward.square")
            }
        }
    }
}

// MARK: - Previews

#Preview("Local Track Table · Populated") {
    @Previewable @State var selectedTrack: LocalTrack?
    let tracks = MSRUPreviewData.localTracks
    let application = MSRUPreviewData.makeApplication()

    LocalTrackTableView(
        tracks: tracks,
        selectedTrack: $selectedTrack,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in }
    )
    .frame(width: 800, height: 400)
}

#Preview("Local Track Table · Empty") {
    @Previewable @State var selectedTrack: LocalTrack?
    let application = MSRUPreviewData.makeApplication()

    LocalTrackTableView(
        tracks: [],
        selectedTrack: $selectedTrack,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in }
    )
    .frame(width: 800, height: 400)
}
