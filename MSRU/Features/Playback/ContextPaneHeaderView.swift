//
//  ContextPaneHeaderView.swift
//  MSRU
//

import SwiftUI
import Observation

struct ContextPaneHeaderView: View {

    @Bindable var scene: SceneModel
    let onClearQueue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker("Context", selection: $scene.activeContextPane) {
                ForEach(SceneModel.ContextPane.allCases) { pane in
                    Text(pane.title).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if scene.activeContextPane == .queue {
                Button {
                    onClearQueue()
                } label: {
                    Text("Clear")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Button {
                scene.isQueuePresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close Details")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview("Context Header") {
    let scene = MSRUPreviewData.makeScene()
    ContextPaneHeaderView(
        scene: scene,
        onClearQueue: {}
    )
    .frame(width: 320)
}
