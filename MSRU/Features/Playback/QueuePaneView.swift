import Foundation
import SwiftUI
import Observation
import AppFoundationUI
import MusicPlayback

struct QueuePaneView: View {
    @Bindable var playback: PlaybackController

    var body: some View {
        if playback.playbackQueue.current == nil && playback.playbackQueue.upcoming.isEmpty {
            ContentUnavailableView("Queue is empty", systemImage: "music.note.list",
                description: Text("Please play a track from the library or browse page."))
        } else {
            List {
                if let current = playback.playbackQueue.current {
                    Section("Now Playing") { row(current, isCurrent: true) }
                }
                if !playback.playbackQueue.upcoming.isEmpty {
                    Section("Up Next") {
                        ForEach(playback.playbackQueue.upcoming) { item in
                            row(item, isCurrent: false)
                                .contextMenu {
                                    Button("Remove from Queue", role: .destructive) {
                                        playback.removeUpcoming(id: item.id)
                                    }
                                }
                        }
                        .onDelete { playback.removeUpcoming(at: $0) }
                        .onMove { playback.moveUpcoming(fromOffsets: $0, toOffset: $1) }
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .hideScrollIndicatorsCompletely()
        }
    }

    private func row(_ queued: PlaybackQueueItem, isCurrent: Bool) -> some View {
        let item = queued.item
        return Button {
            if isCurrent { playback.toggle() }
            else { playback.playQueuedItem(id: queued.id) }
        } label: {
            HStack(spacing: 10) {
                artwork(item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).lineLimit(2)
                    Text(item.subtitle + " · " + item.providerLabel)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: playback.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func artwork(_ item: PlaybackItem) -> some View {
        MediaImageView(
            reference: item.artworkImageReference,
            fixedSize: CGSize(width: 42, height: 42),
            placeholderSystemImage: "music.note",
            cornerRadius: 7
        )
    }


    private var queuePlaceholder: some View {
        Rectangle().fill(.quaternary).overlay {
            Image(systemName: "music.note").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Queue Header View

struct QueueHeaderView: View {
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text("Next").font(.headline)
            Spacer()
            Button(action: onClear) {
                Text("Clear")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview("Queue Header") {
    QueueHeaderView(onClear: {})
        .frame(width: 340)
}


#Preview("Queue · Empty") {
    QueuePaneView(playback: MSRUPreviewData.makePlaybackController())
        .frame(width: 340, height: 700)
}

#Preview("Queue · Mixed Sources") {
    let playback = MSRUPreviewData.makePlaybackController()
    let local = PlaybackItem(local: MSRUPreviewData.localTracks[0])
    let remote = PlaybackItem(openverse: MSRUPreviewData.openverseOne)
    let _ = playback.playbackQueue.start(local, context: [local, remote, local])
    QueuePaneView(playback: playback).frame(width: 340, height: 700)
}
