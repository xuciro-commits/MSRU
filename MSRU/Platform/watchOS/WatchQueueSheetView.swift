//
//  WatchQueueSheetView.swift
//  MSRU
//

import SwiftUI
import Observation

// MARK: - Watch Queue Sheet View

/// Native watchOS lightweight queue view designed for small wrist displays.
/// Shows currently playing item and upcoming queue with immediate tap-to-play.
@MainActor
struct WatchQueueSheetView: View {

    @Bindable var playback: PlaybackController
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if playback.playbackQueue.current == nil && playback.playbackQueue.upcoming.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("Queue is empty"),
                        systemImage: "music.note.list"
                    )
                } else {
                    List {
                        if let current = playback.playbackQueue.current {
                            Section(LocalizedStringKey("Now Playing")) {
                                queueRow(current, isCurrent: true)
                            }
                        }

                        if !playback.playbackQueue.upcoming.isEmpty {
                            Section(LocalizedStringKey("Up Next")) {
                                ForEach(playback.playbackQueue.upcoming) { item in
                                    queueRow(item, isCurrent: false)
                                }
                            }

                            Section {
                                Button(role: .destructive) {
                                    playback.clearUpcoming()
                                } label: {
                                    HStack {
                                        Spacer()
                                        Label(LocalizedStringKey("Clear Queue"), systemImage: "trash")
                                            .font(.footnote)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Queue"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) {
                        onClose()
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func queueRow(_ queued: PlaybackQueueItem, isCurrent: Bool) -> some View {
        let item = queued.item
        return Button {
            if isCurrent {
                playback.toggle()
            } else {
                playback.playQueuedItem(id: queued.id)
                onClose()
            }
        } label: {
            HStack(spacing: 8) {
                if isCurrent {
                    Image(systemName: playback.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Watch Queue Sheet") {
    let playback = MSRUPreviewData.makePlaybackController()
    WatchQueueSheetView(
        playback: playback,
        onClose: {}
    )
    .frame(width: 198, height: 242)
}
