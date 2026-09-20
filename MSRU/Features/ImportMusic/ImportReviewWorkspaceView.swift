//
//  ImportReviewWorkspaceView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import AppFoundation
import AppFoundationUI

struct ImportReviewWorkspaceView: View {
    @Bindable var localStore: LocalLibraryStore
    let onOpenLibrary: () -> Void

    enum WorkspaceState {
        case idle
        case processing(step: String, progress: Double)
        case review(ImportReviewStore)
        case empty(message: String)
        case success(message: String, undoEntries: [FileMoveItem])
    }

    @State private var state: WorkspaceState = .idle
    @State private var isFileImporterPresented: Bool = false
    @State private var isTargetFolderPickerPresented: Bool = false
    @State private var isDropTargeted: Bool = false

    var body: some View {
        Group {
            switch state {
            case .idle:
                dropZoneView

            case .processing(let step, let progress):
                processingView(step: step, progress: progress)

            case .review(let reviewStore):
                ImportReviewView(
                    store: reviewStore,
                    onDismiss: {
                        state = .idle
                    },
                    onCommit: { tracks in
                        Task {
                            await localStore.addTracks(tracks)

                            // Auto-learn acoustic fingerprints and path heuristic rules locally
                            let fingerprinter = AcoustIDFingerprintExtractor()
                            for track in tracks {
                                if let fp = try? await fingerprinter.generateFingerprint(for: track.fileURL) {
                                    LocalFingerprintRegistry.shared.register(
                                        fingerprint: fp.fingerprint,
                                        duration: fp.duration,
                                        title: track.title,
                                        artist: track.artist,
                                        album: track.album,
                                        artworkData: track.artworkData
                                    )
                                }
                                PathHeuristicRuleStore.shared.learnFrom(
                                    folderURL: track.fileURL.deletingLastPathComponent(),
                                    artist: track.artist,
                                    album: track.album
                                )
                            }

                            state = .success(
                                message: "已成功将 \(tracks.count) 首曲目加入资料库，并已记录至本地声纹库与目录规则中（纯路径就地只读引用，原文件保持原样）。",
                                undoEntries: []
                            )
                        }
                    }
                )

            case .empty(let message):
                emptyResultView(message: message)

            case .success(let message, let undoEntries):
                successView(message: message, undoEntries: undoEntries)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: LocalAudioFormatSupport.importContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                startImportPipeline(urls: urls)
            case .failure(let error):
                print("Import file importer failed:", error)
            }
        }
    }

    // MARK: - Drop Zone View

    private var dropZoneView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("音乐导入与审核中心")
                    .font(.system(size: 28, weight: .bold))

                Text("导入本地音乐，进行声纹识别、实体归并和置信度审核。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Drop Area
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isDropTargeted ? Color.accentColor.opacity(0.06) : Color.secondary.opacity(0.03))
                    )

                VStack(spacing: 16) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 54))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)

                    VStack(spacing: 4) {
                        Text("将音乐文件夹或音频文件拖放到这里")
                            .font(.headline)

                        Text("支持 FLAC、MP3、M4A、ALAC、WAV、AAC、AIFF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("选择文件或文件夹…", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
            }
            .frame(maxWidth: 620, minHeight: 260)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Engine Highlights
            HStack(spacing: 32) {
                engineHighlight(
                    icon: "waveform.badge.magnifyingglass",
                    title: "AcoustID 声纹",
                    desc: "基于音频波形的确定性识别"
                )
                engineHighlight(
                    icon: "books.vertical.fill",
                    title: "MusicBrainz 实体",
                    desc: "标准化的发行版与艺术家权威身份"
                )
                engineHighlight(
                    icon: "arrow.triangle.2.circlepath",
                    title: "安全文件整理器",
                    desc: "先模拟验证，支持一键撤销"
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func engineHighlight(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.subheadline.bold())

            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 180)
    }

    // MARK: - Processing View

    private func processingView(step: String, progress: Double) -> some View {
        VStack(spacing: 24) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 320)

            VStack(spacing: 6) {
                Text(step)
                    .font(.headline)

                Text("正在运行 11 步实体归并流程…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success View

    private func successView(message: String, undoEntries: [FileMoveItem]) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("导入完成")
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if !undoEntries.isEmpty {
                    Button("撤销整理") {
                        try? SafeFileOrganizer.undo(executedItems: undoEntries)
                        Task {
                            await localStore.reload()
                            state = .success(message: "撤销完成：文件已还原。", undoEntries: [])
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Button("打开资料库") {
                    onOpenLibrary()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Empty Result View

    private func emptyResultView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("未找到可导入的音频")
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button("重新选择") {
                state = .idle
                isFileImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Handlers

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                    if let directURL = item as? URL {
                        urls.append(directURL)
                    } else if let nsURL = item as? NSURL {
                        urls.append(nsURL as URL)
                    } else if let data = item as? Data, let decoded = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(decoded)
                    }
                }
            }
            if !urls.isEmpty {
                startImportPipeline(urls: urls)
            }
        }
        return true
    }

    private func startImportPipeline(urls: [URL]) {
        state = .processing(step: "正在收集音频文件…", progress: 0.1)

        Task {
            var accessedURLs: [URL] = []
            for u in urls {
                if u.startAccessingSecurityScopedResource() {
                    accessedURLs.append(u)
                }
            }
            defer {
                for u in accessedURLs {
                    u.stopAccessingSecurityScopedResource()
                }
            }

            let audioURLs = collectAudioFiles(from: urls)
            guard !audioURLs.isEmpty else {
                state = .empty(message: "在所选位置未发现受支持的音频文件（支持 FLAC、WAV、MP3、M4A、AAC、AIFF、DTS 等格式）。")
                return
            }

            state = .processing(step: "正在提取 AcoustID 声纹并进行 Picard 聚类…", progress: 0.4)

            let pipeline = ImportPipeline()
            do {
                let report = try await pipeline.process(audioURLs: audioURLs)
                state = .processing(step: "正在准备审核面板…", progress: 0.9)

                let reviewStore = ImportReviewStore(report: report)
                state = .review(reviewStore)
            } catch {
                state = .empty(message: "处理导入文件时发生错误：\(error.localizedDescription)")
            }
        }
    }

    private func collectAudioFiles(from urls: [URL]) -> [URL] {
        var results: [URL] = []

        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    while let fileURL = enumerator.nextObject() as? URL {
                        if LocalAudioFormatSupport.supports(fileURL) {
                            results.append(fileURL)
                        }
                    }
                }
            } else if LocalAudioFormatSupport.supports(url) {
                results.append(url)
            }
        }
        return results
    }
}

// MARK: - Preview

#Preview("Import Review Workspace View") {
    let scene = MSRUPreviewData.makeScene(section: .addMusic)
    ImportReviewWorkspaceView(
        localStore: scene.application.localLibrary,
        onOpenLibrary: {}
    )
    .frame(width: 800, height: 600)
}
