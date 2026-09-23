//
//  SourcesView.swift
//  MSRU
//
//  Navigation surface for Library Sources (Sidebar navigation).
//  Presents connected local directories, NAS, and Subsonic servers with status and sync controls.
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import SubsonicKit
import MusicLibrary
import MusicPlayback

struct SourcesView: View {
    @Bindable var scene: SceneModel
    @State private var coordinator = SourceRuntimeCoordinator.shared
    @State private var isAddServerSheetPresented: Bool = false
    @State private var sourcePendingDelete: Source?
    @State private var isDeleteConfirmationPresented: Bool = false

    init(scene: SceneModel) {
        self.scene = scene
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()

                VStack(spacing: 16) {
                    ForEach(coordinator.activeSources) { source in
                        SourceCardView(
                            source: source,
                            scene: scene,
                            coordinator: coordinator,
                            onRemove: { src in
                                sourcePendingDelete = src
                                isDeleteConfirmationPresented = true
                            }
                        )
                    }
                }

                addSourceFooter
            }
            .padding(28)
        }
        .hideScrollIndicatorsCompletely()
        .task {
            await coordinator.bootstrapAll()
        }
        .sheet(isPresented: $isAddServerSheetPresented) {
            AddSubsonicServerSheet(store: scene.application.subsonicServers) {
                isAddServerSheetPresented = false
                Task {
                    await coordinator.bootstrapAll()
                }
            }
        }
        .confirmationDialog(
            "移除媒体来源",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            if let target = sourcePendingDelete {
                Button("移除 \(target.displayName)", role: .destructive) {
                    Task {
                        await coordinator.removeSource(id: target.id)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("移除此来源后，其索引的曲目与流媒体资产将从媒体库清除。原始服务器上的文件不会受影响。")
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("媒体来源")
                    .font(.largeTitle.bold())

                Text("管理本地音频存储与已连接的极空间 NAS / Subsonic 流媒体服务器。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isAddServerSheetPresented = true
            } label: {
                Label("添加媒体来源", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    private var addSourceFooter: some View {
        Button {
            isAddServerSheetPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("添加极空间 NAS 或 Subsonic / OpenSubsonic 服务器")
                        .font(.body.weight(.medium))
                    Text("支持通过标准协议接入局域网或公网音乐库，享受全格式流媒体点播。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(.secondary.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

// MARK: - Source Card View

private struct SourceCardView: View {
    let source: Source
    @Bindable var scene: SceneModel
    let coordinator: SourceRuntimeCoordinator
    let onRemove: (Source) -> Void

    @State private var stats: (tracks: Int, albums: Int, playlists: Int) = (0, 0, 0)
    @State private var isLoadingStats: Bool = true

    var body: some View {
        let isLocal = SourceID.isLocalSourceID(source.id.rawValue) || source.sourceType == .localFolder
        let isReconciling = coordinator.isReconciling[source.id] == true

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: isLocal ? "internaldrive.fill" : "server.rack")
                    .font(.system(size: 28))
                    .foregroundStyle(isLocal ? Color.accentColor : Color.blue)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isLocal ? Color.accentColor.opacity(0.12) : Color.blue.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(source.displayName)
                            .font(.headline)

                        if isReconciling {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text("同步中…")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                        } else {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text(isLocal ? "就绪" : "在线")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                        }
                    }

                    Text(source.uri)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if isLocal {
                            capabilityBadge("本地解码")
                            capabilityBadge("声纹识别")
                            capabilityBadge("离线可用")
                        } else {
                            if source.capabilities.contains(.supportsStreaming) {
                                capabilityBadge("流媒体播放")
                            }
                            if source.capabilities.contains(.supportsArtwork) {
                                capabilityBadge("封面加载")
                            }
                            if source.capabilities.contains(.supportsStableExternalID) {
                                capabilityBadge("FTS5 检索")
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                if !isLocal {
                    Button(role: .destructive) {
                        onRemove(source)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("移除此来源")
                }
            }

            Divider()

            // Statistics Row
            HStack(spacing: 16) {
                if isLocal {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(stats.tracks) 首歌曲")
                            .font(.caption.monospacedDigit())
                    }

                    Text("•").foregroundStyle(.tertiary).font(.caption2)

                    HStack(spacing: 4) {
                        Image(systemName: "square.stack")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(stats.albums) 张专辑")
                            .font(.caption.monospacedDigit())
                    }

                    Text("•").foregroundStyle(.tertiary).font(.caption2)

                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(stats.playlists) 个歌单")
                            .font(.caption.monospacedDigit())
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("按需在线点播与检索")
                            .font(.caption)
                    }

                    Text("•").foregroundStyle(.tertiary).font(.caption2)

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("OpenSubsonic 直连")
                            .font(.caption)
                    }
                }

                Spacer()

                if let lastReconciled = source.lastReconciledAt {
                    Text("最近连接: \(lastReconciled.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.secondary)

            // Action Buttons
            HStack(spacing: 10) {
                Button {
                    scene.navigateToSource(sourceID: source.id.rawValue, target: .library)
                } label: {
                    Label("浏览歌曲", systemImage: "music.note")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    scene.navigateToSource(sourceID: source.id.rawValue, target: .albums)
                } label: {
                    Label("浏览专辑", systemImage: "square.stack")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    scene.navigateToSource(sourceID: source.id.rawValue, target: .playlists)
                } label: {
                    Label("查看歌单", systemImage: "music.note.list")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if !isLocal {
                    Button {
                        Task {
                            await coordinator.bootstrapSource(source)
                            await loadStats()
                        }
                    } label: {
                        Label(isReconciling ? "检测中..." : "刷新连接", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isReconciling)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary)
        )
        .task {
            await loadStats()
        }
    }

    private func loadStats() async {
        stats = await coordinator.fetchSourceStats(sourceID: source.id)
        isLoadingStats = false
    }

    private func capabilityBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.quaternary))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Feature

enum SourcesFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "sources",
                    group: "Library",
                    title: "Sources",
                    systemImage: "server.rack",
                    route: .section(.sources),
                    order: 140
                )
            ],
            routes: [
                RouteContribution(
                    id: "sources",
                    route: .section(.sources)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "sources",
                route: .section(.sources)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Sources"),
                        systemImage: "server.rack"
                    )
                ) { _ in
                    SourcesView(scene: scene)
                }
            }
        ]
    }
}

// MARK: - Preview

#Preview("Sources View") {
    let scene = MSRUPreviewData.makeScene(section: .sources)
    SourcesView(scene: scene)
        .frame(width: 800, height: 600)
}

#Preview("Local Source Card") {
    let source = Source(
        id: .defaultLocal,
        sourceType: .localFolder,
        uri: "/Preview/Music",
        displayName: "Local Files",
        capabilities: .localFolderDefault,
        isEnabled: true
    )
    SourceCardView(
        source: source,
        scene: MSRUPreviewData.makeScene(section: .sources),
        coordinator: .preview(),
        onRemove: { _ in }
    )
    .frame(width: 700)
    .padding()
}
