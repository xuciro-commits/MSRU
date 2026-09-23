//
//  MSRUContextPaneView.swift
//  MSRU
//

import SwiftUI
import Observation
import MusicLibrary
import MusicPlayback

struct MSRUContextPaneView: View {

    @Bindable var scene: SceneModel
    var onRevealInFinder: ((URL) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ContextPaneHeaderView(
                scene: scene,
                onClearQueue: {
                    scene.application.playback.clearUpcoming()
                }
            )

            Divider()

            switch scene.activeContextPane {
            case .inspector:
                if let station = scene.selectedRadioStation {
                    RadioStationInspectorView(
                        station: station,
                        playback: scene.application.playback,
                        isFavorite: scene.application.radioStore.isFavorite(id: station.id),
                        onToggleFavorite: {
                            scene.application.radioStore.toggleFavorite(id: station.id)
                        },
                        onDelete: station.isCustom ? {
                            scene.application.radioStore.deleteCustomStation(id: station.id)
                            scene.selectedRadioStation = nil
                        } : nil,
                        onClose: {
                            scene.isQueuePresented = false
                        }
                    )
                } else {
                    TrackInspectorView(
                        libraryTrack: scene.selectedLibraryTrack,
                        localTrack: scene.selectedLocalTrack,
                        musicContent: scene.selectedMusicContent,
                        playback: scene.application.playback,
                        library: scene.application.library,
                        localStore: scene.application.localLibrary,
                        onRevealInFinder: onRevealInFinder,
                        onClose: {
                            scene.isQueuePresented = false
                        }
                    )
                }

            case .queue:
                QueuePaneView(
                    playback: scene.application.playback
                )

            case .visualizer:
                VisualizerPaneView(
                    playback: scene.application.playback,
                    onExpandCanvas: {
                        scene.setNowPlaying(presented: true)
                    }
                )

            case .lyrics:
                LyricsPaneView(
                    playback: scene.application.playback,
                    onExpandCanvas: {
                        scene.setNowPlaying(presented: true)
                    }
                )
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
        .tint(Color.accentColor)
    }
}

// MARK: - Context Pane Header View

struct ContextPaneHeaderView: View {

    @Bindable var scene: SceneModel
    let onClearQueue: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(SceneModel.ContextPane.allCases) { pane in
                    let isSelected = scene.activeContextPane == pane
                    Button {
                        scene.activeContextPane = pane
                    } label: {
                        Text(LocalizedStringKey(pane.title))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .background(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if scene.activeContextPane == .queue {
                Button {
                    onClearQueue()
                } label: {
                    Text("Clear")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Button {
                scene.isQueuePresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .padding(5)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close Details")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}


#Preview("Context Pane · Inspector") {
    let scene = MSRUPreviewData.makeScene()
    scene.selectedLocalTrack = MSRUPreviewData.localTracks[0]
    scene.activeContextPane = .inspector
    return MSRUContextPaneView(scene: scene)
        .frame(width: 320, height: 600)
}

#Preview("Context Pane · Radio Inspector") {
    let scene = MSRUPreviewData.makeScene()
    scene.selectedRadioStation = RadioStation.defaultStations[0]
    scene.activeContextPane = .inspector
    return MSRUContextPaneView(scene: scene)
        .frame(width: 320, height: 600)
}

#Preview("Context Pane · Queue") {
    let scene = MSRUPreviewData.makeScene()
    scene.activeContextPane = .queue
    return MSRUContextPaneView(scene: scene)
        .frame(width: 320, height: 600)
}

#Preview("Context Pane · Visualizer") {
    let scene = MSRUPreviewData.makeScene()
    scene.activeContextPane = .visualizer
    return MSRUContextPaneView(scene: scene)
        .frame(width: 320, height: 600)
}

#Preview("Context Pane · Lyrics") {
    let scene = MSRUPreviewData.makeScene()
    scene.activeContextPane = .lyrics
    return MSRUContextPaneView(scene: scene)
        .frame(width: 320, height: 600)
}

#Preview("Context Header") {
    let scene = MSRUPreviewData.makeScene()
    scene.activeContextPane = .queue
    return ContextPaneHeaderView(scene: scene, onClearQueue: {})
        .frame(width: 320)
}
