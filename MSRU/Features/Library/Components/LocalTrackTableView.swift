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
    var onDeleteTracks: ((Set<String>) -> Void)? = nil

    @State private var selectedTrackIDs: Set<String> = []
    @State private var isDeleteConfirmationPresented: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if proxy.size.width < 500 {
                    compactListView
                } else {
                    tableView
                }

                if selectedTrackIDs.count > 1 {
                    floatingBatchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTrackIDs.count)
        .confirmationDialog(
            "确认删除所选歌曲？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("从资料库移除 (\(selectedTrackIDs.count) 首)", role: .destructive) {
                onDeleteTracks?(selectedTrackIDs)
                selectedTrackIDs.removeAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所选歌曲将从本地资料库中移除。原始音频文件将保留在磁盘上。")
        }
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
            TableColumn("标题") { track in
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
            TableColumn("艺术家") { track in
                Text(track.artist)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160)

            // Album column
            TableColumn("专辑") { track in
                Text(track.album ?? "—")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160)

            // Duration column
            TableColumn("时长") { track in
                Text(durationString(track.duration))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 60, max: 70)

            // Favorite column
            TableColumn("收藏") { track in
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
                .help(isSaved ? "从资料库移除" : "加入资料库")
            }
            .width(min: 32, ideal: 36, max: 40)
        }
        .tint(Color.accentColor)
        .scrollIndicators(.hidden)
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
        .scrollIndicators(.hidden)
    }

    private func compactRow(index: Int, track: LocalTrack) -> some View {
        let isSelected = selectedTrackIDs.contains(track.id)
        let isCurrent = isCurrentTrack(track)
        let isSaved = library.contains(local: track)

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

            // Favorite Button
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
            .help(isSaved ? "从资料库移除" : "加入资料库")
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
            selectedTrackIDs = [track.id]
            selectedTrack = track
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                playback.play(track)
            }
        )
        .contextMenu {
            trackContextMenu(track)
        }
    }

    private func trackSubtitle(_ track: LocalTrack) -> String {
        if let album = track.album, !album.isEmpty {
            return "\(track.artist) · \(album)"
        }
        return track.artist
    }

    // MARK: - Floating Batch Bar

    private var floatingBatchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)

            Text("已选择 \(selectedTrackIDs.count) 首歌曲")
                .font(.callout.weight(.medium))

            Spacer()

            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
                if let first = selected.first {
                    playback.toggle(track: first, queue: selected)
                }
            } label: {
                Label("播放所选", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
                for t in selected {
                    playback.addToQueue(t)
                }
            } label: {
                Label("加入队列", systemImage: "text.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            } label: {
                Label("从资料库删除", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("取消选择") {
                selectedTrackIDs.removeAll()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
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
            Label(isCurrentTrack(track) && playback.isPlaying ? "暂停" : "播放",
                  systemImage: isCurrentTrack(track) && playback.isPlaying ? "pause.fill" : "play.fill")
        }

        Button {
            playback.playNext(track)
        } label: {
            Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
        }

        Button {
            playback.addToQueue(track)
        } label: {
            Label("加入队列", systemImage: "text.badge.plus")
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
            Label(isSaved ? "从资料库移除" : "加入资料库",
                  systemImage: isSaved ? "heart.slash" : "heart")
        }

        if let onRevealInFinder {
            Button {
                onRevealInFinder(track.fileURL)
            } label: {
                Label("在访达中显示", systemImage: "arrow.up.forward.square")
            }
        }

        if onDeleteTracks != nil {
            Divider()
            Button(role: .destructive) {
                if selectedTrackIDs.contains(track.id) && selectedTrackIDs.count > 1 {
                    isDeleteConfirmationPresented = true
                } else {
                    onDeleteTracks?([track.id])
                }
            } label: {
                Label(
                    selectedTrackIDs.contains(track.id) && selectedTrackIDs.count > 1
                        ? "从资料库删除所选 (\(selectedTrackIDs.count) 首)"
                        : "从资料库删除",
                    systemImage: "trash"
                )
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

#Preview("Local Track Table · Compact") {
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
    .frame(width: 360, height: 400)
}
