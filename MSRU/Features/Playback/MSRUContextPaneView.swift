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
                TrackInspectorView(
                    localTrack: scene.selectedLocalTrack,
                    musicContent: scene.selectedMusicContent,
                    playback: scene.application.playback,
                    library: scene.application.library,
                    onRevealInFinder: onRevealInFinder,
                    onClose: {
                        scene.isQueuePresented = false
                    }
                )

            case .queue:
                QueuePaneView(
                    playback: scene.application.playback
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

#Preview("Context Pane · Queue") {
    let scene = MSRUPreviewData.makeScene()
    scene.activeContextPane = .queue
    return MSRUContextPaneView(scene: scene)
        .frame(width: 320, height: 600)
}
