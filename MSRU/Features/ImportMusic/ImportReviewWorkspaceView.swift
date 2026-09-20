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
                    }
                )

            case .success(let message, let undoEntries):
                successView(message: message, undoEntries: undoEntries)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: LocalAudioFormatSupport.importContentTypes + [.folder],
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
                Text("Music Import & Review Center")
                    .font(.system(size: 28, weight: .bold))

                Text("Import local music with acoustic fingerprinting, entity resolution, and confidence review.")
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
                        Text("Drag & drop music folder or audio files here")
                            .font(.headline)

                        Text("Supports FLAC, MP3, M4A, ALAC, WAV, AAC, AIFF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Choose Files or Folder...", systemImage: "plus.circle.fill")
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
                    desc: "Deterministic audio waveform recognition"
                )
                engineHighlight(
                    icon: "books.vertical.fill",
                    title: "MusicBrainz Entity",
                    desc: "Standardized canonical release & artist identity"
                )
                engineHighlight(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Safe File Organizer",
                    desc: "Dry-Run verification with one-click Undo"
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

                Text("Running 11-step Identity Resolution Pipeline...")
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
                            state = .success(message: "Undo completed: files reverted.", undoEntries: [])
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

    // MARK: - Handlers

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil),
                   let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
            if !urls.isEmpty {
                startImportPipeline(urls: urls)
            }
        }
        return true
    }

    private func startImportPipeline(urls: [URL]) {
        state = .processing(step: "Collecting audio files...", progress: 0.1)

        Task {
            let audioURLs = collectAudioFiles(from: urls)
            guard !audioURLs.isEmpty else {
                state = .idle
                return
            }

            state = .processing(step: "Extracting AcoustID fingerprints & Picard clustering...", progress: 0.4)

            let pipeline = ImportPipeline()
            do {
                let report = try await pipeline.process(audioURLs: audioURLs)
                state = .processing(step: "Preparing review dashboard...", progress: 0.9)

                let reviewStore = ImportReviewStore(report: report)
                state = .review(reviewStore)
            } catch {
                state = .idle
            }
        }
    }

    private func collectAudioFiles(from urls: [URL]) -> [URL] {
        var results: [URL] = []
        let supportedExtensions = Set(LocalAudioFormatSupport.importContentTypes.compactMap { $0.preferredFilenameExtension?.lowercased() })

        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            results.append(fileURL)
                        }
                    }
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
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
