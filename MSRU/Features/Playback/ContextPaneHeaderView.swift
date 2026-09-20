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

#Preview("Context Header") {
    let scene = MSRUPreviewData.makeScene()
    ContextPaneHeaderView(
        scene: scene,
        onClearQueue: {}
    )
    .frame(width: 320)
}
