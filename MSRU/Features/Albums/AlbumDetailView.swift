//
//  AlbumDetailView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import SubsonicKit
import MusicDomain
import MusicLibrary
import MusicPlayback

struct AlbumDetailView: View {
    let album: AlbumPresentationModel
    let localTracks: [LocalTrack]
    var subsonicServers: SubsonicServerStore? = nil
    @Bindable var playback: PlaybackController
    let onBack: () -> Void
    let onSelectTrack: (LocalTrack) -> Void
    var onDeleteAlbum: (() -> Void)? = nil
    var onFetchArtwork: (() -> Void)? = nil

    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var selectedTrackIDs: Set<String> = []
    @State private var remoteDiscs: [DiscTrackGroup] = []
    @State private var remoteSongs: [SubsonicSongDTO] = []
    @State private var isLoadingRemoteTracks: Bool = false

    private var effectiveTrackCount: Int {
        if !remoteSongs.isEmpty {
            return remoteSongs.count
        }
        return album.trackCount
    }

    private var effectiveDurationString: String {
        let duration: TimeInterval
        if !remoteSongs.isEmpty {
            duration = remoteSongs.reduce(0) { $0 + TimeInterval($1.duration ?? 0) }
        } else {
            duration = album.duration
        }
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Back button & breadcrumb
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.backward")
                        Text("Album")
                    }
                    .font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Hero Header
                HStack(alignment: .bottom, spacing: 24) {
                    ZStack(alignment: .bottomTrailing) {
                        heroArtworkView
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

                        if let badge = album.audioQualityBadge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                            Text("Album")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(album.title)
                            .font(.system(size: 32, weight: .bold))
                            .lineLimit(2)

                        Text(album.artist)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            if let year = album.year {
                                Text("\(year)")
                                Text("•")
                            }
                            if isLoadingRemoteTracks && effectiveTrackCount == 0 {
                                Text("Loading from the server…")
                            } else {
                                Text("\(effectiveTrackCount) songs, \(effectiveDurationString)")
                            }
                            if let badge = album.sourceBadge {
                                Text("•")
                                Text(badge)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.tertiary)

                        if album.versionCount > 1 {
                            Label("\(album.versionCount) Versions", systemImage: "square.stack.3d.down.right")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.quaternary))
                        }

                        HStack(spacing: 12) {
                            Button(action: playAll) {
                                Label("Play", systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: shuffleAll) {
                                Label("Shuffle", systemImage: "shuffle")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)

                            if album.artworkReference == nil, let onFetchArtwork {
                                Button(action: onFetchArtwork) {
                                    Label("Fetch Artwork", systemImage: "arrow.clockwise")
                                        .font(.headline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                            }

                            if onDeleteAlbum != nil {
                                Button(role: .destructive, action: { isDeleteConfirmationPresented = true }) {
                                    Label("Delete Album", systemImage: "trash")
                                        .font(.headline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                if isLoadingRemoteTracks {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading tracks from the server…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }

                // Track Lists by Discs
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(effectiveDiscs) { disc in
                        if effectiveDiscs.count > 1 {
                            Text(disc.discTitle ?? "Disc \(disc.discNumber)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 2) {
                            ForEach(disc.tracks) { trackModel in
                                trackRow(trackModel)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 40)
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
        .confirmationDialog(
            "Delete album \"\(album.title)\"?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete album and all \(album.trackCount) songs", role: .destructive) {
                onDeleteAlbum?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all songs under this album from the local library.")
        }
    }

    private var effectiveDiscs: [DiscTrackGroup] {
        if !remoteDiscs.isEmpty {
            return remoteDiscs
        }
        return album.discs
    }

    private func loadRemoteTracksIfNeeded() async {
        guard album.id.hasPrefix("subsonic:"), let subsonicServers else { return }
        let parts = album.id.split(separator: ":")
        guard parts.count >= 3 else { return }
        let serverID = LibrarySourceID(String(parts[1]))
        let remoteAlbumID = String(parts[2])
        guard let client = subsonicServers.client(for: serverID) else { return }

        isLoadingRemoteTracks = true
        defer { isLoadingRemoteTracks = false }

        do {
            let detailed = try await client.album(id: remoteAlbumID)
            if let songs = detailed.song {
                self.remoteSongs = songs
                let grouped = Dictionary(grouping: songs, by: { $0.discNumber ?? 1 })
                let discs = grouped.keys.sorted().map { discNum -> DiscTrackGroup in
                    let discSongs = grouped[discNum]?.sorted(by: { ($0.track ?? 0) < ($1.track ?? 0) }) ?? []
                    let trackModels = discSongs.map { s in
                        TrackPresentationModel(
                            id: s.id,
                            trackNumber: s.track ?? 1,
                            title: s.title,
                            artist: s.artist ?? album.artist,
                            duration: TimeInterval(s.duration ?? 0),
                            formatBadge: s.suffix?.uppercased()
                        )
                    }
                    return DiscTrackGroup(discNumber: discNum, discTitle: nil, tracks: trackModels)
                }
                self.remoteDiscs = discs
            }
        } catch is CancellationError {
            // Cancelled
        } catch {
            print("[AlbumDetailView] Failed to load remote tracks: \(error)")
        }
    }

    private func makePlaybackItem(for song: SubsonicSongDTO) -> PlaybackItem? {
        guard album.id.hasPrefix("subsonic:"), let subsonicServers else { return nil }
        let parts = album.id.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        let serverID = LibrarySourceID(String(parts[1]))
        let remoteAlbumID = String(parts[2])
        guard let client = subsonicServers.client(for: serverID) else { return nil }

        let streamURL = try? client.streamURL(id: song.id)
        let coverArtURL = try? client.coverArtURL(id: song.coverArt ?? remoteAlbumID)
        return PlaybackItem.subsonic(
            serverID: serverID,
            itemID: song.id,
            title: song.title,
            artist: song.artist ?? album.artist,
            album: album.title,
            streamURL: streamURL,
            coverArtURL: coverArtURL
        )
    }

    private func trackRow(_ trackModel: TrackPresentationModel) -> some View {
        let matchingLocal = localTracks.first { $0.id == trackModel.id }
        let matchingRemote = remoteSongs.first { $0.id == trackModel.id }
        let isCurrent = (matchingLocal != nil && playback.currentTrack?.id == matchingLocal?.id) ||
                        (matchingRemote != nil && playback.currentItem?.subsonicPayload?.itemID == trackModel.id)
        let isPlaying = isCurrent && playback.isPlaying

        let isSelected = selectedTrackIDs.contains(trackModel.id)
        return HStack(spacing: 14) {
            Text("\(trackModel.trackNumber)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(trackModel.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(1)

                if trackModel.artist != album.artist {
                    Text(trackModel.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let badge = trackModel.formatBadge {
                Text(badge)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            Text(trackModel.formattedDuration)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                if let remote = matchingRemote, let item = makePlaybackItem(for: remote) {
                    let allItems = remoteSongs.compactMap { makePlaybackItem(for: $0) }
                    if playback.currentItem?.id == item.id {
                        playback.toggle()
                    } else {
                        playback.play(item, context: allItems)
                    }
                } else if let local = matchingLocal {
                    playback.toggle(track: local, queue: localTracks)
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption)
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
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
                for: trackModel.id,
                selectedIDs: $selectedTrackIDs,
                allIDs: effectiveDiscs.flatMap(\.tracks).map(\.id)
            )
            if let remote = matchingRemote, let item = makePlaybackItem(for: remote) {
                let allItems = remoteSongs.compactMap { makePlaybackItem(for: $0) }
                playback.play(item, context: allItems)
            } else if let local = matchingLocal, selectedTrackIDs.count == 1 {
                onSelectTrack(local)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if let remote = matchingRemote, let item = makePlaybackItem(for: remote) {
                    let allItems = remoteSongs.compactMap { makePlaybackItem(for: $0) }
                    playback.play(item, context: allItems)
                } else if let local = matchingLocal {
                    playback.play(local)
                }
            }
        )
        .contextMenu {
            if let remote = matchingRemote, let item = makePlaybackItem(for: remote) {
                Button("Play Next") {
                    playback.playNext(item)
                }
                Button("Add to Queue") {
                    playback.addToQueue(item)
                }
            } else if let local = matchingLocal {
                Button("Play Next") {
                    playback.playNext(local)
                }
                Button("Add to Queue") {
                    playback.addToQueue(local)
                }
            }
        }
    }

    private func playAll() {
        if !remoteSongs.isEmpty {
            let allItems = remoteSongs.compactMap { makePlaybackItem(for: $0) }
            if let first = allItems.first {
                playback.play(first, context: allItems)
            }
            return
        }
        guard let first = localTracks.first else { return }
        playback.play(first)
    }

    private func shuffleAll() {
        if !remoteSongs.isEmpty {
            let allItems = remoteSongs.shuffled().compactMap { makePlaybackItem(for: $0) }
            if let first = allItems.first {
                playback.play(first, context: allItems)
            }
            return
        }
        guard let first = localTracks.shuffled().first else { return }
        playback.play(first)
    }

    @ViewBuilder
    private var heroArtworkView: some View {
        let reference = album.artworkReference.map { MediaImageReference(relativePath: $0) }
            ?? album.artworkURL.map { MediaImageReference(url: $0) }
        MediaImageView(
            reference: reference,
            thumbnailPixelSize: CGSize(width: 360, height: 360),
            placeholderSystemImage: "music.note",
            cornerRadius: 12
        )
    }

    private var placeholderHeroView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedTrackIDs.count,
            title: "\(selectedTrackIDs.count) songs",
            onDeselect: { selectedTrackIDs.removeAll() }
        ) {
            Button {
                let selected = localTracks.filter { selectedTrackIDs.contains($0.id) }
                if let first = selected.first {
                    playback.toggle(track: first, queue: selected)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = localTracks.filter { selectedTrackIDs.contains($0.id) }
                for t in selected {
                    playback.addToQueue(t)
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Preview

#Preview("Album Detail View") {
    let scene = MSRUPreviewData.makeScene(section: .albums)
    AlbumDetailView(
        album: AlbumPresentationModel(
            id: "preview-album",
            title: "叶惠美",
            artist: "周杰伦",
            year: 2003,
            trackCount: 2,
            duration: 520,
            audioQualityBadge: "Hi-Res 24/96",
            discs: [
                DiscTrackGroup(
                    discNumber: 1,
                    tracks: [
                        TrackPresentationModel(id: "1", trackNumber: 1, title: "以父之名", artist: "周杰伦", duration: 342, formatBadge: "FLAC"),
                        TrackPresentationModel(id: "2", trackNumber: 2, title: "晴天", artist: "周杰伦", duration: 269, formatBadge: "FLAC")
                    ]
                )
            ]
        ),
        localTracks: [],
        playback: scene.application.playback,
        onBack: {},
        onSelectTrack: { _ in }
    )
    .frame(width: 700, height: 600)
}
