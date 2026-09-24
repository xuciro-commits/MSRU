//
//  DeduplicationManagerSheet.swift
//  MSRU
//
//  Created for Professional Music Library Management - Duplicate & Version Detection.
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

public struct DeduplicationManagerSheet: View {

    public let localStore: LocalLibraryStore
    @Bindable public var playback: PlaybackController
    public var onDismiss: () -> Void

    public init(
        localStore: LocalLibraryStore,
        playback: PlaybackController,
        onDismiss: @escaping () -> Void
    ) {
        self.localStore = localStore
        self.playback = playback
        self.onDismiss = onDismiss
    }

    @State private var isScanning: Bool = true
    @State private var scanProgress: Double = 0
    @State private var report: DeduplicationReport? = nil
    @State private var selectedFilter: FilterTab = .all
    @State private var searchQuery: String = ""

    // Deletion states
    @State private var clusterPendingDeletion: DuplicateCluster? = nil
    @State private var isCleanAllConfirmationPresented: Bool = false
    @State private var isProcessingAction: Bool = false
    @State private var actionStatusText: String = ""

    enum FilterTab: String, CaseIterable, Identifiable {
        case all = "All Issues"
        case redundant = "Redundant Files"
        case versions = "Quality Versions"

        var id: String { rawValue }

        var localizedTitle: LocalizedStringKey {
            switch self {
            case .all: return "All Issues"
            case .redundant: return "Redundant Files"
            case .versions: return "Quality Versions"
            }
        }

        var systemImage: String {
            switch self {
            case .all: return "rectangle.stack"
            case .redundant: return "trash"
            case .versions: return "waveform.badge.magnifyingglass"
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if isScanning {
                scanningProgressView
            } else if let report {
                filterAndSearchBar
                Divider()

                if filteredClusters(from: report).isEmpty {
                    cleanEmptyStateView
                } else {
                    clustersListView(report: report)
                }
            } else {
                cleanEmptyStateView
            }

            Divider()
            bottomActionBar
        }
        .frame(minWidth: 700, idealWidth: 780, minHeight: 520, idealHeight: 600)
        .background(Color.platformWindowBackground)
        .task {
            await startScan()
        }
        .confirmationDialog(
            "Clean All Exact Duplicates?",
            isPresented: $isCleanAllConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Move to Trash (\(report?.formattedTotalRecoverable ?? "0 MB"))", role: .destructive) {
                Task {
                    await cleanAllExactDuplicates()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Redundant copies of identical audio files will be moved to the Trash. The highest-quality original will be kept, and all playlists/favorites will remain intact.")
        }
        .confirmationDialog(
            "Clean Redundant Copies of This Song?",
            isPresented: Binding(
                get: { clusterPendingDeletion != nil },
                set: { if !$0 { clusterPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let cluster = clusterPendingDeletion {
                Button("Move \(cluster.redundantItems.count) Duplicate(s) to Trash", role: .destructive) {
                    Task {
                        await cleanCluster(cluster)
                    }
                }
            }
            Button("Cancel", role: .cancel) { clusterPendingDeletion = nil }
        } message: {
            if let cluster = clusterPendingDeletion {
                Text("Redundant copies of \"\(cluster.title)\" will be moved to the Trash. The primary version will be kept.")
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "square.stack.3d.up.badge.automatic")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Deduplication & Version Manager")
                    .font(.title3.weight(.bold))
                Text("Inspect identical duplicate audio files and group multi-quality releases.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Filter and Search Bar

    private var filterAndSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(FilterTab.allCases) { tab in
                    let isSelected = selectedFilter == tab
                    Button {
                        selectedFilter = tab
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.systemImage)
                            Text(tab.localizedTitle)
                            if let report {
                                countBadge(for: tab, report: report, isSelected: isSelected)
                            }
                        }
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Search within duplicates
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Filter by title or artist...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(width: 180)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func countBadge(for tab: FilterTab, report: DeduplicationReport, isSelected: Bool) -> some View {
        let count: Int
        switch tab {
        case .all: count = report.clusters.count
        case .redundant: count = report.clusters.filter(\.isRedundantFileDuplicate).count
        case .versions: count = report.clusters.filter { !$0.isRedundantFileDuplicate }.count
        }

        return Text("\(count)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
    }

    // MARK: - Scanning Progress

    private var scanningProgressView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(value: scanProgress)
                .progressViewStyle(.linear)
                .frame(width: 280)

            VStack(spacing: 4) {
                Text("Analyzing Library for Duplicates & Quality Versions...")
                    .font(.headline)
                Text("\(Int(scanProgress * 100))% completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Clusters List View

    private func clustersListView(report: DeduplicationReport) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Overview metrics banner
                overviewMetricsCard(report: report)

                ForEach(filteredClusters(from: report)) { cluster in
                    clusterCard(cluster)
                }
            }
            .padding(20)
        }
    }

    private func overviewMetricsCard(report: DeduplicationReport) -> some View {
        HStack(spacing: 16) {
            metricItem(
                title: "Redundant Duplicates",
                value: "\(report.exactDuplicateFilesCount)",
                subtext: "Exact identical files",
                systemImage: "trash",
                tint: .orange
            )

            Divider()
                .frame(height: 36)

            metricItem(
                title: "Recoverable Disk Space",
                value: report.formattedTotalRecoverable,
                subtext: "Safe to clean",
                systemImage: "internaldrive",
                tint: .blue
            )

            Divider()
                .frame(height: 36)

            metricItem(
                title: "Quality Version Clusters",
                value: "\(report.versionClustersCount)",
                subtext: "Hi-Res / Codec variants",
                systemImage: "waveform",
                tint: .purple
            )
        }
        .padding(14)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricItem(title: String, value: String, subtext: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func clusterCard(_ cluster: DuplicateCluster) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cluster Card Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(cluster.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Category badge
                categoryPill(cluster.category)

                if cluster.isRedundantFileDuplicate && cluster.recoverableBytes > 0 {
                    Text("Reclaim \(cluster.formattedRecoverableSize)")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.orange)

                    Button {
                        clusterPendingDeletion = cluster
                    } label: {
                        Label("Clean Redundant", systemImage: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            // Cluster Items
            VStack(spacing: 8) {
                ForEach(cluster.items) { item in
                    clusterItemRow(item, in: cluster)
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(cluster.isRedundantFileDuplicate ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func clusterItemRow(_ item: DuplicateItem, in cluster: DuplicateCluster) -> some View {
        let isPlayingThis = playback.isPlaying(trackID: item.track.id)

        return HStack(spacing: 12) {
            // Play / Listen preview button
            Button {
                if isPlayingThis {
                    playback.pause()
                } else {
                    playback.play(item.track)
                }
            } label: {
                Image(systemName: isPlayingThis ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            // Primary vs Redundant Tag
            if item.isPrimary {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Primary")
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.green)
            } else {
                Text(cluster.isRedundantFileDuplicate ? "Duplicate" : "Alternative")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            // Quality pill badge
            Text(item.qualityDescription)
                .font(.caption2.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(item.formattedDuration)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(item.formattedFileSize)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(item.track.fileURL.lastPathComponent)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                PlatformFileViewer.revealInFinder(url: item.track.fileURL)
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            if !item.isPrimary {
                Button(role: .destructive) {
                    Task {
                        await deleteSingleTrack(item.track)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move this file to Trash")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            item.isPrimary ? Color.green.opacity(0.04) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func categoryPill(_ category: DuplicateCategory) -> some View {
        let (label, tint): (String, Color) = {
            switch category {
            case .fileDuplicate:
                return ("Exact File Duplicate", .orange)
            case .differentEncoding:
                return ("Codec Variant", .blue)
            case .qualityDifference:
                return ("Quality Variant", .purple)
            case .differentMaster:
                return ("Different Master", .teal)
            case .differentPerformance:
                return ("Different Performance", .indigo)
            case .none:
                return ("Distinct", .gray)
            }
        }()

        return Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
    }

    // MARK: - Empty State

    private var cleanEmptyStateView: some View {
        ContentUnavailableView {
            Label("No Duplicates Found", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Color.green)
        } description: {
            Text("Your music library is clean! No redundant identical files or unmerged quality duplicates were detected.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            if isProcessingAction {
                ProgressView()
                    .controlSize(.small)
                Text(actionStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let report, report.exactDuplicateFilesCount > 0 {
                Button(role: .destructive) {
                    isCleanAllConfirmationPresented = true
                } label: {
                    Label("Clean All \(report.exactDuplicateFilesCount) Exact Duplicates (Free \(report.formattedTotalRecoverable))", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(isProcessingAction)
            }

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isProcessingAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Filter Logic

    private func filteredClusters(from report: DeduplicationReport) -> [DuplicateCluster] {
        report.clusters.filter { cluster in
            // Filter tab match
            let matchesTab: Bool
            switch selectedFilter {
            case .all:
                matchesTab = true
            case .redundant:
                matchesTab = cluster.isRedundantFileDuplicate
            case .versions:
                matchesTab = !cluster.isRedundantFileDuplicate
            }
            guard matchesTab else { return false }

            // Search query match
            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                return true
            }
            let q = searchQuery.lowercased()
            return cluster.title.lowercased().contains(q) || cluster.artist.lowercased().contains(q)
        }
    }

    // MARK: - Actions

    private func startScan() async {
        isScanning = true
        scanProgress = 0

        let tracks = localStore.tracks
        let service = LibraryDeduplicationService()

        let result = await service.analyze(tracks: tracks) { progress in
            Task { @MainActor in
                self.scanProgress = progress
            }
        }

        self.report = result
        self.isScanning = false
    }

    private func cleanCluster(_ cluster: DuplicateCluster) async {
        isProcessingAction = true
        actionStatusText = "Moving duplicates to Trash..."

        let redundantIDs = Set(cluster.redundantItems.map(\.id))
        _ = await localStore.deleteTracks(withIDs: redundantIDs, deletePhysical: true)

        await startScan()
        isProcessingAction = false
        clusterPendingDeletion = nil
    }

    private func cleanAllExactDuplicates() async {
        guard let report else { return }
        isProcessingAction = true
        actionStatusText = "Cleaning all exact duplicates..."

        var allRedundantIDs: Set<String> = []
        for cluster in report.clusters where cluster.isRedundantFileDuplicate {
            allRedundantIDs.formUnion(cluster.redundantItems.map(\.id))
        }

        if !allRedundantIDs.isEmpty {
            _ = await localStore.deleteTracks(withIDs: allRedundantIDs, deletePhysical: true)
        }

        await startScan()
        isProcessingAction = false
    }

    private func deleteSingleTrack(_ track: LocalTrack) async {
        isProcessingAction = true
        actionStatusText = "Moving track to Trash..."
        _ = await localStore.deleteTracks(withIDs: [track.id], deletePhysical: true)
        await startScan()
        isProcessingAction = false
    }
}

// MARK: - Previews

#Preview("Deduplication Manager") {
    let application = MSRUPreviewData.makeApplication()
    DeduplicationManagerSheet(
        localStore: application.localLibrary,
        playback: application.playback,
        onDismiss: {}
    )
}
