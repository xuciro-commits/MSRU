//
//  ImportReviewView.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 5.
//  Strictly conforms to InteractionAtlas.md Section 11.2.
//

import SwiftUI
import Observation
import AppFoundation

/// Import Review & Resolution Dashboard implementing InteractionAtlas Section 11.2.
struct ImportReviewView: View {

    @Bindable var store: ImportReviewStore
    var onDismiss: (() -> Void)? = nil
    var onCommit: (([LocalTrack]) -> Void)? = nil

    @State private var expandedClusterIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            filterAndSearchBar
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    if !store.aliasSuggestions.isEmpty {
                        aliasSuggestionsSection
                    }

                    clustersTable
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)

            Divider()
            bottomActionBar
        }
        .frame(minWidth: 800, minHeight: 560)
        .background(Color.platformWindowBackground)
        .onAppear {
            // Expand all by default
            expandedClusterIDs = Set(store.pendingReviewClusters.map { $0.id })
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Import Review")
                    .font(.title2.bold())

                Spacer()

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Scanned \(store.totalScannedCount) · Auto-added \(store.autoAcceptedCount) (High Confidence) · Pending \(store.pendingReviewClusters.reduce(0) { $0 + $1.cluster.tracks.count }) · Unidentified \(store.unidentifiedTracks.count) · Potential Duplicates \(store.potentialDuplicatesCount) ")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Filter and Search Bar

    private var filterAndSearchBar: some View {
        HStack(spacing: 14) {
            HStack {
                Picker("Filter", selection: $store.selectedFilter) {
                    ForEach(ReviewFilterOption.allCases) { opt in
                        Text(LocalizedStringKey(opt.rawValue)).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search pending items…", text: $store.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(width: 260)

            HStack {
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Alias Suggestions Section

    private var aliasSuggestionsSection: some View {
        VStack(spacing: 10) {
            ForEach(store.aliasSuggestions) { suggestion in
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Found \(suggestion.variantNames.count) variants: \(suggestion.variantNames.joined(separator: " / "))")
                            .font(.subheadline.bold())

                        Text("Recommend merging to: Entity \(suggestion.canonicalArtistName) (MBID: \(suggestion.canonicalMBID))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        store.mergeAliasSuggestion(id: suggestion.id)
                    } label: {
                        Text("One-Click Merge")
                            .font(.callout.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(14)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Clusters Table

    private var clustersTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Table Header
            HStack {
                Text("Candidate Album / Track")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Fingerprint Confidence")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)

                Text("Matching Candidate (MusicBrainz)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 220, alignment: .leading)

                Text("Action")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 14)

            if store.filteredClusters.isEmpty {
                ContentUnavailableView {
                    Label("No Pending Tracks", systemImage: "checkmark.seal")
                } description: {
                    Text("All imported tracks have been resolved with high confidence or reviewed.")
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ForEach(store.filteredClusters) { clusterResult in
                    clusterRow(clusterResult)
                }
            }
        }
    }

    private func clusterRow(_ clusterResult: AlbumClusterLookupResult) -> some View {
        let isExpanded = expandedClusterIDs.contains(clusterResult.id)
        let isSelected = store.selectedClusterIDs.contains(clusterResult.id)

        return VStack(spacing: 0) {
            // Cluster Header Row
            HStack(spacing: 12) {
                Button {
                    if isExpanded {
                        expandedClusterIDs.remove(clusterResult.id)
                    } else {
                        expandedClusterIDs.insert(clusterResult.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    let albumTitle = clusterResult.matchedRelease?.title ?? clusterResult.cluster.albumName ?? String(localized: "Unknown Album")
                    let artistTitle = clusterResult.matchedRelease?.artist ?? clusterResult.cluster.tracks.compactMap(\.artist).first ?? String(localized: "Unknown Artist")
                    Text("\(albumTitle) - \(artistTitle)")
                        .font(.subheadline.bold())

                    let folderName = clusterResult.cluster.folderURL?.lastPathComponent ?? String(localized: "Unarchived")
                    Text("\(clusterResult.cluster.tracks.count) tracks · Directory: \(folderName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Confidence indicator
                confidenceMeter(clusterResult.confidence)
                    .frame(width: 140, alignment: .leading)

                // Release info
                Text(clusterResult.matchedRelease?.date.map { "Release: \($0)" } ?? String(localized: "Import with local tags"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 220, alignment: .leading)

                // Checkbox toggle
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { newValue in
                        if newValue {
                            store.selectedClusterIDs.insert(clusterResult.id)
                        } else {
                            store.selectedClusterIDs.remove(clusterResult.id)
                        }
                    }
                ))
                .labelsHidden()
                .frame(width: 60, alignment: .trailing)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))

            // Sub-tracks when expanded
            if isExpanded {
                if clusterResult.scoredCandidates.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Multiple matching releases found (click to switch):")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(clusterResult.scoredCandidates) { candidate in
                                    let isCurrent = (clusterResult.matchedRelease?.releaseMBID == candidate.release.releaseMBID)
                                    Button {
                                        store.selectReleaseCandidate(clusterID: clusterResult.id, release: candidate.release)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                                            Text(candidate.disambiguationReason)
                                                .font(.caption2)
                                                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(isCurrent ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.04))
                    Divider()
                }

                VStack(spacing: 0) {
                    ForEach(clusterResult.trackMatches) { trackMatch in
                        trackRow(trackMatch)
                        if trackMatch.id != clusterResult.trackMatches.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(Color.secondary.opacity(0.02))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func trackRow(_ trackMatch: ClusterTrackMatch) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24)

            VStack(alignment: .leading, spacing: 2) {
                let trackNumStr = trackMatch.localTrack.trackNumber.map { String(format: "%02d ", $0) } ?? ""
                Text("\(trackNumStr)\(trackMatch.localTrack.title)")
                    .font(.caption)
                    .lineLimit(1)

                Text(trackMatch.localTrack.fileURL.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            confidenceMeter(trackMatch.score.confidence)
                .frame(width: 140, alignment: .leading)

            Text(trackMatch.candidate?.title ?? String(localized: "Keep Original"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)

            Image(systemName: trackMatch.score.tier == .high ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(trackMatch.score.tier == .high ? Color.green : Color.orange)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.trailing, 12)
    }

    private func confidenceMeter(_ confidence: Double) -> some View {
        HStack(spacing: 6) {
            ProgressView(value: min(1.0, max(0.0, confidence)))
                .progressViewStyle(.linear)
                .tint(confidence >= 0.9 ? Color.green : (confidence >= 0.6 ? Color.blue : Color.orange))
                .frame(width: 70)

            Text(String(format: "%.0f%%", confidence * 100))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 14) {
            Button("Discard Unconfirmed") {
                store.discardUnconfirmed()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Import as Original Files") {
                let tracks = store.importAsOriginalFiles()
                onCommit?(tracks)
            }
            .buttonStyle(.bordered)

            Button("Write Tags and Import (\(store.selectedClusterIDs.count))") {
                Task {
                    let tracks = await store.commitSelectedMatches(writePhysicalTags: true, exportCompanionCover: true)
                    onCommit?(tracks)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.selectedClusterIDs.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.platformWindowBackground)
    }
}

// MARK: - Preview

#Preview("Import Review · Dashboard") {
    let dummyTrack1 = ClusterTrackItem(
        fileURL: URL(fileURLWithPath: "/music/01 以父之名.flac"),
        title: "以父之名",
        artist: "周杰伦",
        album: "叶惠美",
        trackNumber: 1,
        duration: 342.0
    )
    let dummyTrack2 = ClusterTrackItem(
        fileURL: URL(fileURLWithPath: "/music/04 晴天.mp3"),
        title: "晴天",
        artist: "Jay Chou",
        album: "叶惠美",
        trackNumber: 4,
        duration: 269.0
    )

    let cluster = AlbumCluster(
        folderURL: URL(fileURLWithPath: "/music/Jay Chou - 叶惠美"),
        albumName: "叶惠美",
        tracks: [dummyTrack1, dummyTrack2]
    )

    let releaseMatch = ExternalReleaseMatch(
        releaseMBID: "rel_ye_hui_mei",
        title: "叶惠美",
        artist: "周杰伦",
        date: "2003 Taiwan CD",
        trackCount: 11
    )

    let trackMatch1 = ClusterTrackMatch(
        localTrack: dummyTrack1,
        candidate: CatalogTrackCandidate(trackMBID: "rec_1", title: "以父之名", artist: "周杰伦"),
        score: WeightedScoreResult(confidence: 0.96, tier: .high, components: [])
    )
    let trackMatch2 = ClusterTrackMatch(
        localTrack: dummyTrack2,
        candidate: CatalogTrackCandidate(trackMBID: "rec_2", title: "晴天", artist: "周杰伦"),
        score: WeightedScoreResult(confidence: 0.98, tier: .high, components: [])
    )

    let clusterResult = AlbumClusterLookupResult(
        cluster: cluster,
        matchedRelease: releaseMatch,
        confidence: 0.88,
        tier: .medium,
        trackMatches: [trackMatch1, trackMatch2]
    )

    let suggestion = ArtistAliasSuggestion(
        canonicalArtistName: "周杰伦",
        canonicalMBID: "0d79768b-5779-43c3-8857-e6f4a86ff4b8",
        variantNames: ["Jay Chou", "周杰倫", "JAY", "周杰伦"]
    )

    let store = ImportReviewStore(
        totalScannedCount: 16874,
        autoAcceptedCount: 12483,
        pendingReviewClusters: [clusterResult],
        unidentifiedTracks: [],
        potentialDuplicatesCount: 604,
        aliasSuggestions: [suggestion]
    )

    ImportReviewView(store: store)
        .frame(width: 900, height: 600)
}
