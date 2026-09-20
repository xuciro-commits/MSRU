//
//  MetadataManagerWorkspaceView.swift
//  MSRU
//
//  Created for Metadata, Fingerprint & Path Heuristics Management Center.
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI

/// Central Workspace combining Import Review, Local Fingerprint Memory, Path Heuristic Rules, and MusicBrainz Cache.
struct MetadataManagerWorkspaceView: View {

    @Bindable var localStore: LocalLibraryStore
    let onOpenLibrary: () -> Void

    enum ManagerTab: String, CaseIterable, Identifiable {
        case importWorkflow = "导入与审核"
        case providers = "元数据提供商"
        case fingerprints = "声纹记忆库"
        case pathRules = "目录学习规则"
        case cloudCatalog = "MusicBrainz 在线状态"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .importWorkflow: return "tray.and.arrow.down.fill"
            case .providers: return "slider.horizontal.3"
            case .fingerprints: return "waveform.badge.magnifyingglass"
            case .pathRules: return "folder.badge.gearshape"
            case .cloudCatalog: return "globe.badge.chevron.backward"
            }
        }
    }

    @State private var selectedTab: ManagerTab = .importWorkflow
    @State private var fingerprintSearchText: String = ""
    @State private var isAddRulePresented: Bool = false
    @State private var newRulePath: String = ""
    @State private var newRuleArtist: String = ""
    @State private var acoustIDApiKey: String = ""
    @State private var acoustIDTestStatus: String? = nil
    @State private var isVerifyingAcoustID: Bool = false
    @State private var orphanCleanFeedback: String? = nil

    private var fingerprintRegistry = LocalFingerprintRegistry.shared
    private var ruleStore = PathHeuristicRuleStore.shared
    private var providerConfig = MetadataProviderConfigStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Workspace Sub-header Tab Bar
            tabPickerHeader
            Divider()

            // Main Tab Content
            switch selectedTab {
            case .importWorkflow:
                ImportReviewWorkspaceView(
                    localStore: localStore,
                    onOpenLibrary: onOpenLibrary
                )

            case .providers:
                providersConfigView

            case .fingerprints:
                fingerprintsManagementView

            case .pathRules:
                pathRulesManagementView

            case .cloudCatalog:
                cloudCatalogStatusView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isAddRulePresented) {
            addRuleSheet
        }
    }

    // MARK: - Tab Picker Header

    private var tabPickerHeader: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(ManagerTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Badge Metrics Summary
            HStack(spacing: 12) {
                Text("声纹 \(fingerprintRegistry.records.count) 首")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())

                Text("规则 \(ruleStore.rules.count) 条")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Fingerprints Management View

    private var filteredRecords: [AcousticFingerprintRecord] {
        if fingerprintSearchText.isEmpty {
            return fingerprintRegistry.records
        }
        let q = fingerprintSearchText.lowercased()
        return fingerprintRegistry.records.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            ($0.album?.lowercased().contains(q) ?? false) ||
            $0.fingerprint.lowercased().contains(q)
        }
    }

    // MARK: - Providers Configuration View

    private var providersConfigView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("元数据提供商配置")
                        .font(.headline)
                    Text("启用或禁用各个元数据提供方，系统将按照生效的提供商链式拉取权威元数据与高清唱片封面。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(providerConfig.providerPriority) { provider in
                        providerRow(provider)
                    }

                    acoustIDConfigCard
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .task {
                acoustIDApiKey = await AcoustIDConfiguration.shared.apiKey
            }
        }
    }

    private var acoustIDConfigCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Text("AcoustID 声学指纹服务授权 (API Key)")
                    .font(.headline)
                Spacer()
                if let status = acoustIDTestStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("成功") ? .green : .secondary)
                }
            }

            Text("用于通过 Chromaprint 提取的声音特征查询全球 MusicBrainz 录音实体。系统已预设你的专属 API Key，亦可随时修改或测试连通性。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("AcoustID API Key", text: $acoustIDApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: acoustIDApiKey) { _, newValue in
                        Task {
                            await AcoustIDConfiguration.shared.setApiKey(newValue)
                        }
                    }

                Button(action: {
                    Task {
                        isVerifyingAcoustID = true
                        acoustIDTestStatus = "正在验证…"
                        let res = await AcoustIDConfiguration.shared.verifyConnectivity()
                        isVerifyingAcoustID = false
                        acoustIDTestStatus = res.success ? "✓ 验证成功" : "✕ \(res.message)"
                    }
                }) {
                    HStack(spacing: 4) {
                        if isVerifyingAcoustID {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                        }
                        Text("验证连接")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isVerifyingAcoustID || acoustIDApiKey.isEmpty)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func providerRow(_ provider: MetadataProviderType) -> some View {
        let isEnabled = providerConfig.isEnabled(provider)
        let priorityIndex = (providerConfig.providerPriority.firstIndex(of: provider) ?? 0) + 1

        return HStack(spacing: 16) {
            Image(systemName: provider.iconName)
                .font(.title2)
                .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    (isEnabled ? Color.accentColor : Color.secondary).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(provider.displayName)
                        .font(.headline)

                    Text("第 \(priorityIndex) 优先级")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                Text(provider.providerDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { providerConfig.setEnabled(provider, isEnabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isEnabled ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Fingerprints Management View

    private var fingerprintsManagementView: some View {
        VStack(spacing: 0) {
            // Filter & Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索声纹、歌曲或歌手…", text: $fingerprintSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: 320)

                Spacer()

                if let feedback = orphanCleanFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                if !fingerprintRegistry.records.isEmpty {
                    Button("清理未引用声纹") {
                        let cleaned = fingerprintRegistry.cleanOrphanRecords(activeTracks: localStore.tracks)
                        orphanCleanFeedback = cleaned > 0 ? "已清理 \(cleaned) 条未引用声纹" : "暂无孤立声纹"
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            orphanCleanFeedback = nil
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Button("清空声纹记忆") {
                        fingerprintRegistry.removeAll()
                        orphanCleanFeedback = "已清空全部声纹"
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            orphanCleanFeedback = nil
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            if filteredRecords.isEmpty {
                ContentUnavailableView {
                    Label("暂无已学习的声纹", systemImage: "waveform.badge.magnifyingglass")
                } description: {
                    Text("通过“导入与审核”中心导入或在右侧检查器中标记歌曲后，其 PCM 声纹将永久保存在本地，下次导入时秒级命中。")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRecords) { record in
                            fingerprintRow(record)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func fingerprintRow(_ record: AcousticFingerprintRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(record.title)
                        .font(.headline)

                    Text("· \(record.artist)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let album = record.album {
                        Text("(\(album))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 10) {
                    Text("指纹: \(record.fingerprint.prefix(16))…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)

                    Text("时长: \(durationString(record.duration))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("命中: \(record.matchCount) 次")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)

                    Text("学习时间: \(record.dateLearned.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                fingerprintRegistry.remove(fingerprint: record.fingerprint)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Path Rules Management View

    private var pathRulesManagementView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("目录匹配规则让系统根据文件夹名称（如“男歌手/王力宏”）自动归属歌手，无需在线查询。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    isAddRulePresented = true
                } label: {
                    Label("添加新规则…", systemImage: "plus")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            if ruleStore.rules.isEmpty {
                ContentUnavailableView {
                    Label("暂无目录学习规则", systemImage: "folder.badge.gearshape")
                } description: {
                    Text("当导入分类文件夹（如“男歌手/王力宏”）时，系统会自动提炼并学习目录特征；你也可以点击上方手动添加。")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(ruleStore.rules) { rule in
                            ruleRow(rule)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func ruleRow(_ rule: PathHeuristicRule) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("路径包含: \"\(rule.pathPattern)\"")
                        .font(.headline.monospaced())

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("归属歌手: \(rule.targetArtist)")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)

                    if let album = rule.targetAlbum, !album.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("专辑: \(album)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("累计生效: \(rule.matchCount) 次")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    Text("添加时间: \(rule.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                ruleStore.removeRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Cloud Catalog Status View

    private var cloudCatalogStatusView: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 6) {
                Text("MusicBrainz 官方在线目录服务")
                    .font(.title2.bold())

                Text("全局权威音乐元数据与发行版数据库 (https://musicbrainz.org)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                statusRow(title: "连接状态", value: "已接入 (HTTP Web Service 2.0)", icon: "checkmark.circle.fill", color: .green)
                statusRow(title: "开源合规速率限制", value: "内置 1.0 秒/请求安全节流阀 (防止 IP 拦截)", icon: "gauge.with.needle.fill", color: .blue)
                statusRow(title: "缓存策略", value: "首次在线命中后自动持久化至本地声纹库，二次查询 0ms", icon: "bolt.shield.fill", color: .orange)
                statusRow(title: "封面来源", value: "Cover Art Archive 官方归档服务", icon: "photo.stack.fill", color: .purple)
            }
            .padding(20)
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: 520)

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.bold())
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Add Rule Sheet

    private var addRuleSheet: some View {
        VStack(spacing: 20) {
            Text("添加目录学习规则")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("路径关键词 (例如：男歌手/王力宏)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("路径特征", text: $newRulePath)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("对应歌手实体名")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("歌手名称", text: $newRuleArtist)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(width: 320)

            HStack(spacing: 12) {
                Button("取消") {
                    isAddRulePresented = false
                }
                .buttonStyle(.bordered)

                Button("保存规则") {
                    ruleStore.addRule(pathPattern: newRulePath, targetArtist: newRuleArtist)
                    newRulePath = ""
                    newRuleArtist = ""
                    isAddRulePresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newRulePath.trimmingCharacters(in: .whitespaces).isEmpty || newRuleArtist.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview("Metadata Manager Workspace View") {
    let scene = MSRUPreviewData.makeScene(section: .addMusic)
    MetadataManagerWorkspaceView(
        localStore: scene.application.localLibrary,
        onOpenLibrary: {}
    )
    .frame(width: 900, height: 600)
}
