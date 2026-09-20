//
//  MSRUContextPaneView.swift
//  MSRU
//

import SwiftUI
import Observation

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
