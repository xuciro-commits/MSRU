//
//  ImportReviewWorkspaceView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import AppFoundation
import AppFoundationUI
import MusicDomain
import MusicLibrary

struct ImportReviewWorkspaceView: View {
    @Bindable var localStore: LocalLibraryStore
    var watchedFolders: WatchedFolderStore? = nil
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
                            try? await localStore.addTracks(tracks)

                            state = .success(
                                message: "Successfully added \(tracks.count) tracks to the library.",
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
                if (error as? CocoaError)?.code != .userCancelled {
                    print("Import file importer failed:", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Drop Zone View

    private var dropZoneView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Music Import & Review Center")
                    .font(.system(size: 28, weight: .bold))

                Text("Import local music, perform fingerprinting, entity resolution, and confidence review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let watchedFolders, !watchedFolders.folders.isEmpty {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)

                        let activeCount = watchedFolders.folders.filter(\.isEnabled).count
                        Text("Watched Folders: \(activeCount) active directory(ies)")
                            .font(.caption.bold())

                        Spacer()

                        if let first = watchedFolders.folders.first(where: \.isEnabled) {
                            Text(first.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Button {
                            Task {
                                await watchedFolders.rescanAll()
                            }
                        } label: {
                            Label("Rescan", systemImage: "arrow.clockwise")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(maxWidth: 620)
                    .padding(.top, 6)
                }
            }
            .padding(.top, 30)

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
                        Text("Drag and drop music folders or audio files here")
                            .font(.headline)

                        Text("Supports FLAC, MP3, M4A, ALAC, WAV, AAC, AIFF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Select Files or Folders…", systemImage: "plus.circle.fill")
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
                    title: "AcoustID Fingerprint",
                    desc: "Deterministic recognition based on audio waveforms"
                )
                engineHighlight(
                    icon: "books.vertical.fill",
                    title: "MusicBrainz Entity",
                    desc: "Standardized releases and canonical artist identities"
                )
                engineHighlight(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Safe File Organizer",
                    desc: "Dry-run verification first, supports one-click undo"
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

            Text(LocalizedStringKey(title))
                .font(.subheadline.bold())

            Text(LocalizedStringKey(desc))
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
                Text(LocalizedStringKey(step))
                    .font(.headline)

                Text("Running 11-step entity resolution pipeline…")
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

            Text("Import Completed")
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if !undoEntries.isEmpty {
                    Button("Undo Organization") {
                        try? SafeFileOrganizer.undo(executedItems: undoEntries)
                        Task {
                            await localStore.reload()
                            state = .success(message: "Undo complete: Files restored.", undoEntries: [])
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Button("Open Library") {
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

            Text("No importable audio found")
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button("Reselect") {
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
        state = .processing(step: "Collecting audio files…", progress: 0.1)

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
                state = .empty(message: "No supported audio files found in the selected location (supports FLAC, WAV, MP3, M4A, AAC, AIFF, DTS, etc.).")
                return
            }

            state = .processing(step: "Extracting AcoustID and performing Picard clustering…", progress: 0.4)

            let pipeline = ImportPipeline()
            do {
                let report = try await pipeline.process(audioURLs: audioURLs)
                state = .processing(step: "Preparing review panel…", progress: 0.9)

                let reviewStore = ImportReviewStore(report: report)
                state = .review(reviewStore)
            } catch {
                state = .empty(message: "Error processing import files: \(error.localizedDescription)")
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
    let scene = MSRUPreviewData.makeScene(section: .importReview)
    ImportReviewWorkspaceView(
        localStore: scene.application.localLibrary,
        onOpenLibrary: {}
    )
    .frame(width: 800, height: 600)
}
