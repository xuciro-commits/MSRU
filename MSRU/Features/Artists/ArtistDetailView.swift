//
//  ArtistDetailView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import MediaLibrary
import SubsonicKit
import MusicDomain
import MusicLibrary
import MusicPlayback

struct ArtistDetailView: View {
    let artist: ArtistPresentationModel
    let tracks: [LocalTrack]
    var subsonicServers: SubsonicServerStore? = nil
    @Bindable var playback: PlaybackController
    let onBack: () -> Void
    let onSelectTrack: (LocalTrack) -> Void
    let onSelectAlbum: (AlbumPresentationModel) -> Void
    var onDeleteArtist: (() -> Void)? = nil

    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var biographyRecord: ArtistBiographyRecord? = nil
    @State private var isBioExpanded: Bool = false
    @State private var selectedTrackIDs: Set<String> = []
    @State private var remoteAlbums: [AlbumPresentationModel] = []
    @State private var remoteTopTracks: [LocalTrack] = []
    @State private var isLoadingRemote: Bool = false

    private var albums: [AlbumPresentationModel] {
        if artist.id.hasPrefix("subsonic:") {
            return remoteAlbums
        }
        return LibraryPresentationAggregator.buildAlbums(from: tracks).filter {
            $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) == artist.name
        }
    }

    private var topTracks: [LocalTrack] {
        if artist.id.hasPrefix("subsonic:") {
            return remoteTopTracks
        }
        return Array(tracks.prefix(5))
    }

    private var effectiveTracks: [LocalTrack] {
        artist.id.hasPrefix("subsonic:") ? remoteTopTracks : tracks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Back button & breadcrumb
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.backward")
                        Text("Artist")
                    }
                    .font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Hero Header
                HStack(alignment: .center, spacing: 24) {
                    artistArtworkView
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artist")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(artist.name)
                            .font(.system(size: 36, weight: .bold))
                            .lineLimit(1)

                        // Aliases tags
                        if !artist.aliases.isEmpty {
                            HStack(spacing: 6) {
                                Text("Aliases: ")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                ForEach(artist.aliases, id: \.self) { alias in
                                    Text(alias)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        }

                        Text(artist.displaySubtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)

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

                            if onDeleteArtist != nil && !artist.id.hasPrefix("subsonic:") {
                                Button(role: .destructive, action: { isDeleteConfirmationPresented = true }) {
                                    Label("Delete Artist", systemImage: "trash")
                                        .font(.headline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                // Artist Biography & Background Section
                if let bio = biographyRecord {
                    artistBiographyCard(bio)
                        .padding(.horizontal, 24)
                }

                // Top Tracks Section
                if !topTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Songs")
                            .font(.title2.bold())
                            .padding(.horizontal, 24)

                        VStack(spacing: 2) {
                            ForEach(Array(topTracks.enumerated()), id: \.element.id) { index, track in
                                trackRow(track, number: index + 1)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Discography Section
                if !albums.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Albums")
                            .font(.title2.bold())
                            .padding(.horizontal, 24)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)],
                            spacing: 24
                        ) {
                            ForEach(albums) { album in
                                AlbumCardView(
                                    album: album,
                                    onSelect: {
                                        onSelectAlbum(album)
                                    },
                                    onPlay: {
                                        if album.id.hasPrefix("subsonic:"), let subsonicServers {
                                            let parts = album.id.split(separator: ":")
                                            if parts.count >= 3 {
                                                let serverID = LibrarySourceID(String(parts[1]))
                                                let remoteAlbumID = String(parts[2])
                                                if let client = subsonicServers.client(for: serverID) {
                                                    Task {
                                                        if let detailed = try? await client.album(id: remoteAlbumID),
                                                           let songs = detailed.song, !songs.isEmpty {
                                                            let items = songs.compactMap { song -> PlaybackItem? in
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
                                                            if let first = items.first {
                                                                playback.play(first, context: items)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        } else if let first = tracks.first(where: { $0.album == album.title }) {
                                            playback.play(first)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .hideScrollIndicatorsCompletely()
        .overlay(alignment: .bottom) {
            if selectedTrackIDs.count > 1 {
                floatingBatchBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTrackIDs.count)
        .task {
            if biographyRecord == nil {
                biographyRecord = await ArtistBiographyService.shared.fetchBiography(artistName: artist.name)
            }
        }
        .task(id: artist.id) {
            if artist.id.hasPrefix("subsonic:"), let subsonicServers {
                let parts = artist.id.split(separator: ":")
                if parts.count >= 3 {
                    let serverID = LibrarySourceID(String(parts[1]))
                    let remoteArtistID = String(parts[2])
                    if let client = subsonicServers.client(for: serverID),
                       let server = subsonicServers.server(for: serverID) {
                        isLoadingRemote = true
                        defer { isLoadingRemote = false }
                        do {
                            let artistDTO = try await client.artist(id: remoteArtistID)
                            let albumDTOs = artistDTO.album ?? []
                            let mappedAlbums = albumDTOs.map { albumDTO -> AlbumPresentationModel in
                                let coverArtURL = try? client.coverArtURL(id: albumDTO.coverArt ?? albumDTO.id)
                                return AlbumPresentationModel(
                                    id: "subsonic:\(serverID.rawValue):\(albumDTO.id)",
                                    title: albumDTO.effectiveTitle,
                                    artist: albumDTO.artist ?? artist.name,
                                    year: albumDTO.year,
                                    artworkURL: coverArtURL,
                                    artworkReference: coverArtURL?.absoluteString,
                                    trackCount: albumDTO.songCount ?? 0,
                                    duration: TimeInterval(albumDTO.duration ?? 0),
                                    audioQualityBadge: nil,
                                    sourceBadge: server.name,
                                    versionCount: 1,
                                    discs: []
                                )
                            }
                            self.remoteAlbums = mappedAlbums

                            var sampledSongs: [LocalTrack] = []
                            for albumDTO in mappedAlbums.prefix(2) {
                                let albumParts = albumDTO.id.split(separator: ":")
                                if albumParts.count >= 3 {
                                    let albumID = String(albumParts[2])
                                    if let detailed = try? await client.album(id: albumID),
                                       let songs = detailed.song {
                                        for s in songs.prefix(3) {
                                            if let streamURL = try? client.streamURL(id: s.id) {
                                                let coverURL = try? client.coverArtURL(id: s.coverArt ?? albumID)
                                                sampledSongs.append(
                                                    LocalTrack(
                                                        fileURL: streamURL,
                                                        title: s.title,
                                                        artist: s.artist ?? artist.name,
                                                        album: s.album ?? albumDTO.title,
                                                        duration: TimeInterval(s.duration ?? 0),
                                                        artworkReference: coverURL?.absoluteString,
                                                        trackNumber: s.track,
                                                        year: s.year
                                                    )
                                                )
                                            }
                                        }
                                    }
                                }
                                if sampledSongs.count >= 5 { break }
                            }
                            self.remoteTopTracks = sampledSongs
                        } catch is CancellationError {
                            // Cancelled
                        } catch {
                            print("[ArtistDetailView] Failed to load remote artist: \(error)")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete artist \"\(artist.name)\"?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cascade delete artist and all content", role: .destructive) {
                onDeleteArtist?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This operation will perform a cascade delete, removing all albums and songs of this artist from the local library. This action cannot be undone.")
        }
    }

    private func artistBiographyCard(_ bio: ArtistBiographyRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Artist Bio")
                    .font(.headline)

                if let span = bio.lifeSpan {
                    Text("· \(span)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let country = bio.country {
                    Text("(\(country))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if let url = bio.sourceURL {
                    Link(destination: url) {
                        Label("Wikipedia", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }

            if !bio.genres.isEmpty {
                HStack(spacing: 6) {
                    ForEach(bio.genres.prefix(4), id: \.self) { genre in
                        Text(genre.capitalized)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            Text(bio.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .lineLimit(isBioExpanded ? nil : 3)

            Button(isBioExpanded ? "Show Less" : "Read More") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isBioExpanded.toggle()
                }
            }
            .buttonStyle(.plain)
            .font(.caption.bold())
            .foregroundStyle(Color.accentColor)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private func trackRow(_ track: LocalTrack, number: Int) -> some View {
        let isCurrent = playback.currentTrack?.id == track.id
        let isPlaying = isCurrent && playback.isPlaying
        let isSelected = selectedTrackIDs.contains(track.id)

        return HStack(spacing: 14) {
            Text("\(number)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(1)

                if let album = track.album {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatDuration(track.duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                playback.toggle(track: track, queue: tracks)
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
                for: track.id,
                selectedIDs: $selectedTrackIDs,
                allIDs: topTracks.map(\.id)
            )
            if selectedTrackIDs.count == 1 {
                onSelectTrack(track)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                playback.play(track)
            }
        )
        .contextMenu {
            Button("Play Next") {
                playback.playNext(track)
            }
            Button("Add to Queue") {
                playback.addToQueue(track)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let min = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", min, sec)
    }

    private func playAll() {
        guard let first = effectiveTracks.first else { return }
        playback.toggle(track: first, queue: effectiveTracks)
    }

    private func shuffleAll() {
        guard let first = effectiveTracks.shuffled().first else { return }
        playback.toggle(track: first, queue: effectiveTracks.shuffled())
    }

    @ViewBuilder
    private var artistArtworkView: some View {
        let reference = artist.artworkReference.map { MediaImageReference(relativePath: $0) }
            ?? artist.artworkURL.map { MediaImageReference(url: $0) }
        MediaImageView(
            reference: reference,
            thumbnailPixelSize: CGSize(width: 320, height: 320),
            placeholderSystemImage: "music.mic",
            isCircular: true
        )
    }

    private var placeholderArtistView: some View {
        Circle()
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedTrackIDs.count,
            title: "\(selectedTrackIDs.count) songs",
            onDeselect: { selectedTrackIDs.removeAll() }
        ) {
            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
                if let first = selected.first {
                    playback.toggle(track: first, queue: selected)
                }
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
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

#Preview("Artist Detail View") {
    let scene = MSRUPreviewData.makeScene(section: .artists)
    ArtistDetailView(
        artist: ArtistPresentationModel(
            id: "preview-artist",
            name: "周杰伦",
            aliases: ["Jay Chou", "周董"],
            country: "TW",
            albumCount: 2,
            trackCount: 20
        ),
        tracks: [],
        playback: scene.application.playback,
        onBack: {},
        onSelectTrack: { _ in },
        onSelectAlbum: { _ in }
    )
    .frame(width: 800, height: 600)
}
