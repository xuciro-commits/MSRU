//
//  RemoteServerListView.swift
//  MSRU
//
//  Settings section displaying configured Subsonic/OpenSubsonic servers with status.
//

import SwiftUI
import MediaLibrary
import SubsonicKit
import AppFoundationUI

struct RemoteServerListView: View {
    @Bindable var store: SubsonicServerStore
    @State private var isAddSheetPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("远程媒体服务与 NAS")
                        .font(.headline)
                    Text("连接极空间、Navidrome 等兼容 Subsonic / OpenSubsonic 协议的远程流媒体服务器。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isAddSheetPresented = true
                } label: {
                    Label("添加服务器", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if store.servers.isEmpty {
                emptyState
            } else {
                serverList
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sheet(isPresented: $isAddSheetPresented) {
            AddSubsonicServerSheet(store: store) {
                isAddSheetPresented = false
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("暂未添加远程服务器")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("点击右上角「添加服务器」即可接入极空间、Navidrome 等音乐库。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var serverList: some View {
        VStack(spacing: 10) {
            ForEach(store.servers) { server in
                HStack(spacing: 14) {
                    Image(systemName: server.kind == .subsonic ? "externaldrive.connected.to.line.below.fill" : "server.rack")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(server.name)
                                .font(.body)
                                .fontWeight(.semibold)

                            statusPill(server.state)
                        }

                        HStack(spacing: 6) {
                            if let url = server.serverURL {
                                Text(url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let user = server.username {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text("用户: \(user)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let error = server.errorMessage {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        Task {
                            await store.pingServer(id: server.id)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("测试连接与刷新状态")

                    Button(role: .destructive) {
                        store.removeServer(id: server.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("移除此服务器")
                }
                .padding(12)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func statusPill(_ state: LibrarySourceState) -> some View {
        switch state {
        case .online:
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("在线").font(.caption2).foregroundStyle(.green)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.green.opacity(0.12), in: Capsule())

        case .offline:
            HStack(spacing: 4) {
                Circle().fill(.secondary).frame(width: 6, height: 6)
                Text("离线").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())

        case .syncing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("同步中").font(.caption2).foregroundStyle(.blue)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.opacity(0.12), in: Capsule())

        case .authenticationRequired:
            HStack(spacing: 4) {
                Circle().fill(.orange).frame(width: 6, height: 6)
                Text("需要认证").font(.caption2).foregroundStyle(.orange)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.12), in: Capsule())

        case .error:
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text("异常").font(.caption2).foregroundStyle(.red)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.red.opacity(0.12), in: Capsule())
        }
    }
}

#Preview {
    RemoteServerListView(
        store: SubsonicServerStore(
            credentialStore: InMemorySubsonicCredentialStore(),
            registry: LibraryProviderRegistry()
        )
    )
    .padding()
    .frame(width: 650)
}
