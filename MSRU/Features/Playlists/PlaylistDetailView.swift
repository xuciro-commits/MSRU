//
//  PlaylistDetailView.swift
//  MSRU
//

import SwiftUI
import AppFoundation

@MainActor
struct PlaylistDetailView: View {
    @Bindable var playlistStore: PlaylistStore
    let playlist: Playlist
    let tracks: [LocalTrack]
    let playback: PlaybackController
    var onBack: () -> Void
    var onSelectTrack: ((LocalTrack) -> Void)?

    @State private var isEditSheetPresented = false
    @State private var isDeleteConfirmationPresented = false

    private var resolvedTracks: [LocalTrack] {
        playlist.trackIDs.compactMap { id in
            tracks.first { $0.id == id }
        }
    }

    private var totalDurationString: String {
        let total = resolvedTracks.reduce(0) { $0 + $1.duration }
        let mins = Int(total) / 60
        let secs = Int(total) % 60
        return mins > 0 ? "\(mins) min \(secs) sec" : "\(secs) sec"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Navigation Back Bar
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(LocalizedStringKey("Playlists"))
                    }
                    .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Hero Header
                HStack(alignment: .bottom, spacing: 24) {
                    heroArtwork
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("PLAYLIST"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(playlist.title)
                            .font(.system(size: 32, weight: .bold))
                            .lineLimit(2)

                        if let desc = playlist.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        HStack(spacing: 6) {
                            Text("\(resolvedTracks.count) songs")
                            if !resolvedTracks.isEmpty {
                                Text("•")
                                Text(totalDurationString)
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.tertiary)

                        HStack(spacing: 12) {
                            Button(action: playAll) {
                                Label(LocalizedStringKey("Play"), systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(resolvedTracks.isEmpty)

                            Button(action: shuffleAll) {
                                Label(LocalizedStringKey("Shuffle"), systemImage: "shuffle")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .disabled(resolvedTracks.isEmpty)

                            Button(action: { isEditSheetPresented = true }) {
                                Label(LocalizedStringKey("Edit"), systemImage: "pencil")
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive, action: { isDeleteConfirmationPresented = true }) {
                                Label(LocalizedStringKey("Delete"), systemImage: "trash")
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)

                // Track List
                if resolvedTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey("No songs in this playlist yet"))
                            .font(.headline)
                        Text(LocalizedStringKey("Add songs from your library by right clicking any track."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(resolvedTracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(index: index + 1, track: track)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $isEditSheetPresented) {
            NewPlaylistSheetView(
                initialTitle: playlist.title,
                initialDescription: playlist.description ?? "",
                onSave: { newTitle, newDesc in
                    Task {
                        await playlistStore.updatePlaylist(id: playlist.id, title: newTitle, description: newDesc)
                    }
                }
            )
        }
        .confirmationDialog(
            LocalizedStringKey("Delete Playlist"),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                Task {
                    await playlistStore.deletePlaylist(id: playlist.id)
                    onBack()
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete this playlist? This action cannot be undone."))
        }
    }

    // MARK: - Hero Artwork

    private var heroArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note.list")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Track Row

    private func trackRow(index: Int, track: LocalTrack) -> some View {
        let isCurrent = playback.currentTrack?.id == track.id
        return HStack(spacing: 12) {
            // Index or Speaker
            ZStack {
                if isCurrent && playback.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(index)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24)

            // Small artwork
            if let data = track.artworkData, let image = Image(artworkData: data) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            // Title & Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Album
            if let album = track.album, !album.isEmpty {
                Text(album)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }

            // Duration
            Text(durationString(track.duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            // Menu
            Menu {
                Button {
                    playback.playNext(track)
                } label: {
                    Label(LocalizedStringKey("Play Next"), systemImage: "text.line.first.and.arrowtriangle.forward")
                }

                Button {
                    playback.addToQueue(track)
                } label: {
                    Label(LocalizedStringKey("Add to Queue"), systemImage: "text.badge.plus")
                }

                Divider()

                Button(role: .destructive) {
                    Task {
                        await playlistStore.removeTrack(track.id, from: playlist.id)
                    }
                } label: {
                    Label(LocalizedStringKey("Remove from Playlist"), systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectTrack?(track)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                playback.toggle(track: track, queue: resolvedTracks)
            }
        )
    }

    // MARK: - Actions

    private func playAll() {
        guard let first = resolvedTracks.first else { return }
        playback.play(first, queue: resolvedTracks)
    }

    private func shuffleAll() {
        guard !resolvedTracks.isEmpty else { return }
        let shuffled = resolvedTracks.shuffled()
        if let first = shuffled.first {
            playback.play(first, queue: shuffled)
        }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Previews

#Preview("Playlist Detail View") {
    let playback = MSRUPreviewData.makePlaybackController()
    let playlistStore = PlaylistStore(repository: PreviewPlaylistRepository(playlists: [
        Playlist(
            title: "Night Drive Vibes",
            description: "Late night atmospheric synthwave and ambient beats.",
            trackIDs: MSRUPreviewData.localTracks.map(\.id)
        )
    ]))
    PlaylistDetailView(
        playlistStore: playlistStore,
        playlist: playlistStore.playlists[0],
        tracks: MSRUPreviewData.localTracks,
        playback: playback,
        onBack: {}
    )
    .frame(width: 700, height: 600)
}
