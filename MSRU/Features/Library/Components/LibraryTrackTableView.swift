//
//  LibraryTrackTableView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

struct LibraryTrackTableView: View {

    let tracks: [LibraryTrack]
    @Binding var selectedTrack: LibraryTrack?
    @Bindable var playback: PlaybackController
    @Bindable var library: LibraryStore

    var onRevealInFinder: ((URL) -> Void)? = nil

    @State private var selectedTrackIDs: Set<UUID> = []

    var body: some View {
        GeometryReader { proxy in
            Group {
                if proxy.size.width < 500 {
                    compactListView
                } else {
                    tableView
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .bottom) {
                if selectedTrackIDs.count > 1 {
                    floatingBatchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTrackIDs.count)
        .onChange(of: selectedTrackIDs) { _, newIDs in
            if let firstID = newIDs.first, let found = tracks.first(where: { $0.id == firstID }) {
                if selectedTrack?.id != found.id {
                    selectedTrack = found
                }
            } else if newIDs.isEmpty {
                selectedTrack = nil
            }
        }
        .onChange(of: selectedTrack?.id) { _, newSelectedID in
            if let newSelectedID, !selectedTrackIDs.contains(newSelectedID) {
                selectedTrackIDs = [newSelectedID]
            }
        }
        .onAppear {
            if let id = selectedTrack?.id {
                selectedTrackIDs = [id]
            }
        }
    }

    // MARK: - Table View

    private var tableView: some View {
        Table(tracks, selection: $selectedTrackIDs) {
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
            TableColumn("Duration") { track in
                Text(durationString(track.duration))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 60, max: 70)

            // Library membership column
            TableColumn("In Library") { track in
                let isSaved = library.contains(id: track.id)
                Button {
                    Task {
                        if isSaved {
                            await library.remove(id: track.id)
                        } else {
                            await library.add(track)
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isSaved ? Color.accentColor : Color.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help(isSaved ? "Remove from Library" : "Add to Library")
            }
            .width(min: 32, ideal: 36, max: 40)
        }
        .tint(Color.accentColor)
        .hideScrollIndicatorsCompletely()
        .contextMenu(forSelectionType: UUID.self) { selection in
            if let firstID = selection.first, let track = tracks.first(where: { $0.id == firstID }) {
                trackContextMenu(track)
            }
        } primaryAction: { selection in
            let selected = tracks.filter { selection.contains($0.id) }
            if let first = selected.first {
                playback.toggle(library: first, queue: selected.isEmpty ? tracks : selected)
            }
        }
    }

    // MARK: - Compact List View

    private var compactListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    compactRow(index: index, track: track)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .hideScrollIndicatorsCompletely()
    }

    private func compactRow(index: Int, track: LibraryTrack) -> some View {
        let isSelected = selectedTrackIDs.contains(track.id)
        let isCurrent = isCurrentTrack(track)
        let isSaved = library.contains(id: track.id)

        return HStack(spacing: 10) {
            // Artwork / Playing state
            ZStack {
                trackArtwork(track)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if isCurrent {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 32, height: 32)

                    Image(systemName: playback.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
            }

            // Title & Subtitle (Artist · Album)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)

                Text(trackSubtitle(track))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Duration
            Text(durationString(track.duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            // Library membership button
            Button {
                Task {
                    if isSaved {
                        await library.remove(id: track.id)
                    } else {
                        await library.add(track)
                    }
                }
            } label: {
                Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSaved ? Color.accentColor : Color.secondary)
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help(isSaved ? "Remove from Library" : "Add to Library")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            SelectionHelper.handleTap(clickedID: track.id, allIDs: tracks.map(\.id), selection: &selectedTrackIDs)
            selectedTrack = track
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                playback.toggle(library: track, queue: tracks)
            }
        )
        .contextMenu {
            trackContextMenu(track)
        }
    }

    // MARK: - Floating Batch Bar

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedTrackIDs.count,
            title: String(localized: "\(selectedTrackIDs.count) songs"),
            onDeselect: { selectedTrackIDs.removeAll() }
        ) {
            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
                if let first = selected.first {
                    playback.toggle(library: first, queue: selected)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
                for track in selected {
                    if let item = PlaybackItem(library: track) {
                        playback.addToQueue(item)
                    }
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
                Task {
                    for track in selected where library.contains(id: track.id) {
                        await library.remove(id: track.id)
                    }
                }
            } label: {
                Label("Remove from Library", systemImage: "minus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func trackSubtitle(_ track: LibraryTrack) -> String {
        if let album = track.album, !album.isEmpty {
            return "\(track.artist) · \(album)"
        }
        return track.artist
    }


    // MARK: - Helpers

    private func isCurrentTrack(_ track: LibraryTrack) -> Bool {
        let item = PlaybackItem(library: track)
        return playback.currentItem?.id == item?.id
    }

    private func durationString(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "—" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    @ViewBuilder
    private func trackArtwork(_ track: LibraryTrack) -> some View {
        MediaImageView(
            reference: track.artworkReference ?? track.artworkURL?.absoluteString,
            fixedSize: CGSize(width: 36, height: 36),
            thumbnailPixelSize: CGSize(width: 72, height: 72),
            cornerRadius: 6
        )
    }

    @ViewBuilder
    private func trackContextMenu(_ track: LibraryTrack) -> some View {
        Button {
            playback.toggle(library: track, queue: tracks)
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

        let isSaved = library.contains(id: track.id)
        Button {
            Task {
                if isSaved {
                    await library.remove(id: track.id)
                } else {
                    await library.add(track)
                }
            }
        } label: {
            Label(isSaved ? "Remove from Library" : "Add to Library",
                  systemImage: isSaved ? "minus.circle" : "plus.circle")
        }

        if let localURL = track.sources.first(where: { $0.kind == .local && $0.localFileURL != nil })?.localFileURL,
           let onRevealInFinder {
            Button {
                onRevealInFinder(localURL)
            } label: {
                Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
            }
        }
    }
}

// MARK: - Previews

#Preview("Library Track Table · Populated") {
    @Previewable @State var selectedTrack: LibraryTrack?
    let tracks = MSRUPreviewData.localTracks.map { LibraryTrack(local: $0) }
    let application = MSRUPreviewData.makeApplication(savedTracks: tracks)

    LibraryTrackTableView(
        tracks: tracks,
        selectedTrack: $selectedTrack,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in }
    )
    .frame(width: 800, height: 400)
}

#Preview("Library Track Table · Empty") {
    @Previewable @State var selectedTrack: LibraryTrack?
    let application = MSRUPreviewData.makeApplication()

    LibraryTrackTableView(
        tracks: [],
        selectedTrack: $selectedTrack,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in }
    )
    .frame(width: 800, height: 400)
}

#Preview("Library Track Table · Compact") {
    @Previewable @State var selectedTrack: LibraryTrack?
    let tracks = MSRUPreviewData.localTracks.map { LibraryTrack(local: $0) }
    let application = MSRUPreviewData.makeApplication(savedTracks: tracks)

    LibraryTrackTableView(
        tracks: tracks,
        selectedTrack: $selectedTrack,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in }
    )
    .frame(width: 360, height: 400)
}
