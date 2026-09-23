//
//  PlaylistDetailView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import MediaLibrary
import SubsonicKit
import MusicLibrary
import MusicPlayback

@MainActor
struct PlaylistDetailView: View {
    @Bindable var playlistStore: PlaylistStore
    let playlist: Playlist
    let tracks: [LocalTrack]
    var subsonicServers: SubsonicServerStore? = nil
    let playback: PlaybackController
    var onBack: () -> Void
    var onSelectTrack: ((LocalTrack) -> Void)?

    @State private var isEditSheetPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var selectedTrackIDs: Set<String> = []
    @State private var remoteTracks: [LocalTrack] = []
    @State private var isLoadingRemoteTracks: Bool = false

    private var currentPlaylist: Playlist {
        playlistStore.playlists.first { $0.id == playlist.id } ?? playlist
    }

    private var resolvedTracks: [LocalTrack] {
        if !remoteTracks.isEmpty {
            return remoteTracks
        }
        if currentPlaylist.isSmart {
            return playlistStore.resolveTracks(for: currentPlaylist, from: tracks)
        }
        return currentPlaylist.trackIDs.compactMap { id in
            tracks.first { $0.id == id || $0.fileURL.lastPathComponent == id || $0.fileURL.absoluteString.contains(id) }
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
                        Text(currentPlaylist.isSmart ? "SMART PLAYLIST" : "PLAYLIST")
                            .font(.caption.bold())
                            .foregroundStyle(currentPlaylist.isSmart ? Color.purple : Color.secondary)

                        Text(currentPlaylist.title)
                            .font(.system(size: 32, weight: .bold))
                            .lineLimit(2)

                        if let desc = currentPlaylist.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        HStack(spacing: 6) {
                            if isLoadingRemoteTracks && resolvedTracks.isEmpty {
                                Text("正在从远程媒体服务加载…")
                            } else {
                                Text("\(resolvedTracks.count) songs")
                                if !resolvedTracks.isEmpty {
                                    Text("•")
                                    Text(totalDurationString)
                                }
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

                if isLoadingRemoteTracks {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在从远程服务加载歌单曲目...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }

                // Track List
                if resolvedTracks.isEmpty && !isLoadingRemoteTracks {
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
                } else if !resolvedTracks.isEmpty {
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
        .hideScrollIndicatorsCompletely()
        .task {
            await loadRemoteTracksIfNeeded()
        }
        .overlay(alignment: .bottom) {
            if selectedTrackIDs.count > 1 {
                floatingBatchBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTrackIDs.count)
        .sheet(isPresented: $isEditSheetPresented) {
            NewPlaylistSheetView(
                initialTitle: currentPlaylist.title,
                initialDescription: currentPlaylist.description ?? "",
                initialRules: currentPlaylist.rules,
                onSave: { newTitle, newDesc, newRules in
                    Task {
                        await playlistStore.updatePlaylist(
                            id: currentPlaylist.id,
                            title: newTitle,
                            description: newDesc,
                            rules: newRules,
                            updateRules: true
                        )
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
                    await playlistStore.deletePlaylist(id: currentPlaylist.id)
                    onBack()
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete this playlist? This action cannot be undone."))
        }
    }

    // MARK: - Hero Artwork

    @ViewBuilder
    private var heroArtwork: some View {
        if let ref = currentPlaylist.artworkReference {
            MediaImageView(
                reference: ref,
                thumbnailPixelSize: CGSize(width: 320, height: 320),
                placeholderSystemImage: "music.note.list",
                cornerRadius: 12
            )
        } else {
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
    }

    // MARK: - Track Row

    private func trackRow(index: Int, track: LocalTrack) -> some View {
        let isCurrent = playback.currentTrack?.id == track.id
        let isSelected = selectedTrackIDs.contains(track.id)
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
            MediaImageView(
                reference: track.artworkReference,
                fixedSize: CGSize(width: 36, height: 36),
                cornerRadius: 6
            )

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
                        await playlistStore.removeTrack(track.id, from: currentPlaylist.id)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : (isCurrent ? Color.accentColor.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            SelectionHelper.handleTap(
                for: track.id,
                selectedIDs: $selectedTrackIDs,
                allIDs: resolvedTracks.map(\.id)
            )
            if selectedTrackIDs.count == 1 {
                onSelectTrack?(track)
            }
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

    // MARK: - Remote Loading

    private func loadRemoteTracksIfNeeded() async {
        guard let desc = currentPlaylist.description,
              let idRangeStart = desc.range(of: "[id:"),
              let idRangeEnd = desc.range(of: "]", range: idRangeStart.upperBound..<desc.endIndex),
              let subsonicServers else {
            return
        }
        let remotePlaylistID = String(desc[idRangeStart.upperBound..<idRangeEnd.lowerBound])

        guard let server = subsonicServers.servers.first(where: { desc.contains($0.name) }) ?? subsonicServers.servers.first,
              let client = subsonicServers.client(for: server.id) else {
            return
        }

        isLoadingRemoteTracks = true
        defer { isLoadingRemoteTracks = false }

        do {
            let detail = try await client.playlist(id: remotePlaylistID)
            let songs = detail.entry ?? []
            let mapped: [LocalTrack] = songs.compactMap { song in
                guard let streamURL = try? client.streamURL(id: song.id) else { return nil }
                let coverURL = try? client.coverArtURL(id: song.coverArt ?? song.id)
                return LocalTrack(
                    fileURL: streamURL,
                    title: song.title,
                    artist: song.artist ?? "Unknown Artist",
                    album: song.album ?? "Unknown Album",
                    duration: TimeInterval(song.duration ?? 0),
                    artworkReference: coverURL?.absoluteString,
                    trackNumber: song.track,
                    year: song.year
                )
            }
            self.remoteTracks = mapped
        } catch is CancellationError {
            // Cancelled
        } catch {
            print("[PlaylistDetailView] Failed to load remote playlist tracks: \(error)")
        }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedTrackIDs.count,
            title: "\(selectedTrackIDs.count) songs",
            onDeselect: { selectedTrackIDs.removeAll() }
        ) {
            Button {
                let selected = resolvedTracks.filter { selectedTrackIDs.contains($0.id) }
                if let first = selected.first {
                    playback.toggle(track: first, queue: selected)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = resolvedTracks.filter { selectedTrackIDs.contains($0.id) }
                for t in selected {
                    playback.addToQueue(t)
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                let toRemove = selectedTrackIDs
                Task {
                    for id in toRemove {
                        await playlistStore.removeTrack(id, from: currentPlaylist.id)
                    }
                    selectedTrackIDs.removeAll()
                }
            } label: {
                Label(LocalizedStringKey("Remove from Playlist"), systemImage: "minus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
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
