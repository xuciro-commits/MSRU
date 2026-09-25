//
//  LibraryCleanupView.swift
//  MSRU
//
//  One workspace for cleaning the library: a health overview (duplicates,
//  incomplete info, missing artwork) with batch fixes, import review,
//  fingerprint memory and folder rules. Built from system containers so the
//  platform supplies materials and layout.
//

import SwiftUI
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

struct LibraryCleanupView: View {
    let cleanup: LibraryCleanupModel
    let localStore: LocalLibraryStore
    let playback: PlaybackController
    var watchedFolders: WatchedFolderStore? = nil
    let fingerprints: LocalFingerprintRegistry
    let acoustID: AcoustIDConfiguration
    let folderRules: PathHeuristicRuleStore
    let onOpenLibrary: () -> Void

    @State private var page: Page = .overview
    @State private var isDuplicateReviewPresented = false

    enum Page: String, CaseIterable, Identifiable {
        case overview
        case importReview
        case fingerprints
        case folderRules

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .overview: "Overview"
            case .importReview: "Import Review"
            case .fingerprints: "Fingerprints"
            case .folderRules: "Folder Rules"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.vertical, 12)

            Divider()

            switch page {
            case .overview:
                LibraryHealthOverview(
                    cleanup: cleanup,
                    onReviewDuplicates: { isDuplicateReviewPresented = true }
                )
            case .importReview:
                ImportReviewWorkspaceView(
                    localStore: localStore,
                    watchedFolders: watchedFolders,
                    onOpenLibrary: onOpenLibrary
                )
            case .fingerprints:
                FingerprintMemoryView(localStore: localStore, fingerprints: fingerprints, acoustID: acoustID)
            case .folderRules:
                FolderRulesView(rules: folderRules)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            cleanup.scanIfNeeded()
        }
        .sheet(isPresented: $isDuplicateReviewPresented, onDismiss: { cleanup.scan() }) {
            DeduplicationManagerSheet(
                localStore: localStore,
                playback: playback,
                candidatePaths: cleanup.report?.duplicateCandidatePaths ?? [],
                onDismiss: { isDuplicateReviewPresented = false }
            )
        }
    }
}

// MARK: - Health Overview

private struct LibraryHealthOverview: View {
    let cleanup: LibraryCleanupModel
    let onReviewDuplicates: () -> Void

    var body: some View {
        Form {
            Section {
                statusRow
                if let message = cleanup.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Library Health")
            } footer: {
                Text("Checks the local files in your library. Fixes change the library, never your audio files.")
            }

            if let report = cleanup.report {
                Section("Issues") {
                    issueRow(
                        title: "Possible Duplicates",
                        systemImage: "square.on.square",
                        count: report.duplicateGroups.count,
                        detail: Text("\(report.possibleExtraCopies) extra copies. Review them before anything is moved to the Trash.")
                    ) {
                        Button("Review…", action: onReviewDuplicates)
                    }

                    issueRow(
                        title: "Incomplete Info",
                        systemImage: "text.badge.xmark",
                        count: report.incompleteInfoPaths.count,
                        detail: Text("Placeholder titles: \(report.placeholderTitleCount) · Unknown artists: \(report.unknownArtistCount) · Missing albums: \(report.missingAlbumCount)")
                    ) {
                        Button("Get Info") { cleanup.fix(.info) }
                    }

                    issueRow(
                        title: "Missing Artwork",
                        systemImage: "photo.on.rectangle.angled",
                        count: report.missingArtworkPaths.count,
                        detail: Text("Looks for cover art in the folder, then in the music catalogue.")
                    ) {
                        Button("Find Artwork") { cleanup.fix(.artwork) }
                    }
                }

                if let result = cleanup.lastFix {
                    Section("Last Fix") {
                        fixResult(result)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Status

    @ViewBuilder
    private var statusRow: some View {
        switch cleanup.phase {
        case .scanning(let progress):
            progressRow(
                Text("Scanning \(progress.scanned) of \(progress.total) songs…"),
                value: progress.fraction
            )
        case .fixing(let fix, let done, let total):
            progressRow(
                fix == .info
                    ? Text("Getting info: \(done) of \(total) songs…")
                    : Text("Finding artwork: \(done) of \(total) songs…"),
                value: total > 0 ? Double(done) / Double(total) : 0
            )
        case .idle:
            if let report = cleanup.report {
                LabeledContent {
                    Button("Scan Again") { cleanup.scan() }
                } label: {
                    if report.isClean {
                        Label("No issues found in \(report.trackCount) songs", systemImage: "checkmark.seal")
                    } else {
                        Text("\(report.trackCount) songs checked")
                    }
                    Text("Scanned \(report.scannedAt, format: .relative(presentation: .named))")
                }
            } else {
                LabeledContent {
                    Button("Scan Library") { cleanup.scan() }
                        .buttonStyle(.borderedProminent)
                } label: {
                    Text("Not scanned yet")
                }
            }
        }
    }

    private func progressRow(_ title: Text, value: Double) -> some View {
        HStack(spacing: 12) {
            ProgressView(value: value) {
                title
            }
            Button("Stop") { cleanup.cancel() }
        }
    }

    // MARK: Issues

    private func issueRow(
        title: LocalizedStringKey,
        systemImage: String,
        count: Int,
        detail: Text,
        @ViewBuilder action: () -> some View
    ) -> some View {
        LabeledContent {
            HStack(spacing: 12) {
                Text(count, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(count > 0 ? .primary : .secondary)
                action()
                    .disabled(count == 0 || cleanup.isBusy)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    detail
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: count > 0 ? systemImage : "checkmark.circle")
            }
        }
    }

    private func fixResult(_ result: LibraryCleanupModel.FixResult) -> some View {
        switch result.fix {
        case .info:
            Text("Get Info checked \(result.checked) songs: \(result.resolved) now complete, \(result.after) still incomplete.")
        case .artwork:
            Text("Artwork search checked \(result.checked) songs: \(result.resolved) found, \(result.after) still missing.")
        }
    }
}

// MARK: - Fingerprint Memory

private struct FingerprintMemoryView: View {
    let localStore: LocalLibraryStore
    let fingerprints: LocalFingerprintRegistry
    let acoustID: AcoustIDConfiguration

    @State private var records: [AcousticFingerprintRecord] = []
    @State private var searchText = ""
    @State private var apiKey = ""
    @State private var keyStatus: LocalizedStringKey?
    @State private var isVerifying = false
    @State private var feedback: LocalizedStringKey?
    @State private var isClearAllConfirmationPresented = false

    private var filteredRecords: [AcousticFingerprintRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return records }
        return records.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
                || ($0.album?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Application Key") {
                    HStack {
                        TextField("Application Key", text: $apiKey)
                            .labelsHidden()
                            .font(.body.monospaced())
                            .onSubmit { Task { await acoustID.setApiKey(apiKey) } }
                        Button("Verify") { verifyKey() }
                            .disabled(isVerifying || apiKey.isEmpty)
                        Button("Use Default") {
                            Task {
                                await acoustID.resetToDefault()
                                apiKey = await acoustID.apiKey
                                keyStatus = nil
                            }
                        }
                    }
                }
                if let keyStatus {
                    Text(keyStatus)
                        .foregroundStyle(.secondary)
                }
                Link("Register your own key at acoustid.org", destination: URL(string: "https://acoustid.org/new-application")!)
            } header: {
                Text("AcoustID")
            } footer: {
                Text("Fingerprints are looked up on AcoustID to identify songs whose tags are missing or wrong.")
            }

            Section {
                if records.isEmpty {
                    Text("No fingerprints learned yet. They are saved when songs are identified during import.")
                        .foregroundStyle(.secondary)
                } else if filteredRecords.isEmpty {
                    Text("No fingerprints match your search.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredRecords) { record in
                        fingerprintRow(record)
                    }
                }
            } header: {
                HStack {
                    Text("Learned Fingerprints (\(records.count))")
                    Spacer()
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                }
            } footer: {
                HStack {
                    if let feedback {
                        Text(feedback)
                    }
                    Spacer()
                    Button("Remove Orphaned") { cleanOrphans() }
                        .disabled(records.isEmpty)
                    Button("Remove All…", role: .destructive) { isClearAllConfirmationPresented = true }
                        .disabled(records.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            apiKey = await acoustID.apiKey
            await reload()
        }
        .confirmationDialog("Remove all learned fingerprints?", isPresented: $isClearAllConfirmationPresented) {
            Button("Remove All", role: .destructive) {
                Task {
                    await fingerprints.removeAll()
                    await reload()
                    feedback = "All fingerprints removed."
                }
            }
        } message: {
            Text("Songs are not affected. Fingerprints are learned again the next time songs are identified.")
        }
    }

    private func fingerprintRow(_ record: AcousticFingerprintRecord) -> some View {
        LabeledContent {
            Button(role: .destructive) {
                Task {
                    await fingerprints.remove(fingerprint: record.fingerprint)
                    await reload()
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove this fingerprint")
        } label: {
            Text(record.title)
            Text("\(record.artist) · \(Duration.seconds(record.duration).formatted(.time(pattern: .minuteSecond))) · Matched \(record.matchCount) times")
        }
    }

    private func reload() async {
        records = await fingerprints.records
    }

    private func verifyKey() {
        isVerifying = true
        keyStatus = "Verifying…"
        Task {
            await acoustID.setApiKey(apiKey)
            let result = await acoustID.verifyConnectivity()
            let status: LocalizedStringKey = result.success ? "The key works." : LocalizedStringKey(result.message)
            keyStatus = status
            isVerifying = false
        }
    }

    private func cleanOrphans() {
        Task {
            do {
                let active = try await localStore.fingerprintCleanupReferences()
                let removed = await fingerprints.cleanOrphanRecords(activeKeys: active.keys, activePaths: active.paths)
                await reload()
                let message: LocalizedStringKey = removed > 0
                    ? "Removed \(removed) fingerprints of songs no longer in the library."
                    : "No orphaned fingerprints."
                feedback = message
            } catch {
                feedback = LocalizedStringKey(error.localizedDescription)
            }
        }
    }
}

// MARK: - Folder Rules

private struct FolderRulesView: View {
    let rules: PathHeuristicRuleStore

    @State private var isAddRulePresented = false
    @State private var newPattern = ""
    @State private var newArtist = ""

    var body: some View {
        Form {
            Section {
                if rules.rules.isEmpty {
                    Text("No folder rules yet. Rules are learned when you import organized folders, or you can add one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rules.rules) { rule in
                        LabeledContent {
                            Button(role: .destructive) {
                                rules.removeRule(id: rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove this rule")
                        } label: {
                            Text(verbatim: rule.pathPattern)
                                .font(.body.monospaced())
                            Text("→ \(rule.targetArtist) · Used \(rule.matchCount) times")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Folder Rules")
                    Spacer()
                    Button("Add Rule…") { isAddRulePresented = true }
                }
            } footer: {
                Text("When a file's path contains the pattern, its artist is set without an online lookup.")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isAddRulePresented) {
            addRuleSheet
        }
    }

    private var addRuleSheet: some View {
        NavigationStack {
            addRuleForm
        }
    }

    private var addRuleForm: some View {
        Form {
            Section("Add Folder Rule") {
                TextField("Path contains", text: $newPattern, prompt: Text(verbatim: "Pop/Artist"))
                TextField("Artist", text: $newArtist)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { isAddRulePresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    rules.addRule(pathPattern: newPattern, targetArtist: newArtist)
                    newPattern = ""
                    newArtist = ""
                    isAddRulePresented = false
                }
                .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty || newArtist.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Feature

enum LibraryCleanupFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "library-cleanup",
                    group: "Source & Import",
                    title: "Library Cleanup",
                    systemImage: "wand.and.stars",
                    route: .section(.importReview),
                    order: 220
                )
            ],
            routes: [
                RouteContribution(
                    id: "library-cleanup",
                    route: .section(.importReview)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "library-cleanup",
                route: .section(.importReview)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: String(localized: "Library Cleanup"),
                        systemImage: "wand.and.stars"
                    )
                ) { _ in
                    let application = scene.application
                    LibraryCleanupView(
                        cleanup: application.cleanup,
                        localStore: application.localLibrary,
                        playback: application.playback,
                        watchedFolders: application.watchedFolders,
                        fingerprints: application.services.fingerprints,
                        acoustID: application.services.acoustID,
                        folderRules: application.services.folderRules,
                        onOpenLibrary: {
                            scene.send(.navigate(.section(.library)))
                        }
                    )
                }
            }
        ]
    }
}

// MARK: - Preview

#Preview("Library Cleanup") {
    let application = MSRUPreviewData.makeApplication()
    LibraryCleanupView(
        cleanup: application.cleanup,
        localStore: application.localLibrary,
        playback: application.playback,
        fingerprints: application.services.fingerprints,
        acoustID: application.services.acoustID,
        folderRules: application.services.folderRules,
        onOpenLibrary: {}
    )
    .frame(width: 900, height: 650)
}

#Preview("Health Overview") {
    let track = { (path: String, format: String) in
        LibraryHealthTrack(path: path, title: "Hotel California", artist: "Eagles", duration: 390,
                           format: format, bitrateKbps: nil, fileSize: 40_000_000)
    }
    let report = LibraryHealthReport(
        trackCount: 14_980,
        duplicateGroups: [LibraryDuplicateCandidateGroup(tracks: [track("/m/a.flac", "FLAC"), track("/m/b.mp3", "MP3")])],
        incompleteInfoPaths: Array(repeating: "/m/x.mp3", count: 312),
        missingArtworkPaths: Array(repeating: "/m/y.mp3", count: 87),
        placeholderTitleCount: 120,
        unknownArtistCount: 64,
        missingAlbumCount: 245
    )
    LibraryHealthOverview(
        cleanup: LibraryCleanupModel(library: MSRUPreviewData.makeLocalLibraryStore(), report: report),
        onReviewDuplicates: {}
    )
    .frame(width: 800, height: 520)
}

#Preview("Fingerprints") {
    let application = MSRUPreviewData.makeApplication()
    FingerprintMemoryView(
        localStore: application.localLibrary,
        fingerprints: application.services.fingerprints,
        acoustID: application.services.acoustID
    )
    .frame(width: 800, height: 520)
}

#Preview("Folder Rules") {
    FolderRulesView(rules: MSRUPreviewData.makeApplication().services.folderRules)
        .frame(width: 800, height: 400)
}
