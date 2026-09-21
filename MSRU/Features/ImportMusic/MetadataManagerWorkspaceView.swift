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
    var watchedFolders: WatchedFolderStore? = nil
    let onOpenLibrary: () -> Void

    enum ManagerTab: String, CaseIterable, Identifiable {
        case importWorkflow = "Import & Review"
        case providers = "Metadata Providers"
        case fingerprints = "Fingerprint Memory"
        case pathRules = "Folder Learning Rules"
        case cloudCatalog = "MusicBrainz Online Status"

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
    @State private var fingerprintRecords: [AcousticFingerprintRecord] = []

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
                    watchedFolders: watchedFolders,
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
        .background(Color.platformWindowBackground)
        .sheet(isPresented: $isAddRulePresented) {
            addRuleSheet
        }
        .task {
            await loadFingerprintRecords()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .fingerprints {
                Task {
                    await loadFingerprintRecords()
                }
            }
        }
    }

    private func loadFingerprintRecords() async {
        let records = await LocalFingerprintRegistry.shared.records
        self.fingerprintRecords = records
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
                        Label(LocalizedStringKey(tab.rawValue), systemImage: tab.systemImage)
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
                Text("Fingerprints \(fingerprintRecords.count) tracks")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())

                Text("Rules \(ruleStore.rules.count) entries")
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
            return fingerprintRecords
        }
        let q = fingerprintSearchText.lowercased()
        return fingerprintRecords.filter {
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
                    Text("Metadata Provider Configuration")
                        .font(.headline)
                    Text("Enable or disable metadata providers. The system will chain-fetch authoritative metadata and HD cover art through active providers.")
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
                Text("AcoustID Application Client Key")
                    .font(.headline)
                Spacer()
                if let status = acoustIDTestStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("Success") ? .green : .red)
                }
            }

            Text("Used for querying global MusicBrainz recordings via Chromaprint.\nNote: AcoustID distinguishes between Application Key and User Key. Query service must use Application Key.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("AcoustID Client API Key", text: $acoustIDApiKey)
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
                        acoustIDTestStatus = "Verifying…"
                        let res = await AcoustIDConfiguration.shared.verifyConnectivity()
                        isVerifyingAcoustID = false
                        acoustIDTestStatus = res.success ? "✓ Verification successful" : "✕ \(res.message)"
                    }
                }) {
                    HStack(spacing: 4) {
                        if isVerifyingAcoustID {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                        }
                        Text("Verify Connection")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isVerifyingAcoustID || acoustIDApiKey.isEmpty)

                Button("Restore Default") {
                    Task {
                        await AcoustIDConfiguration.shared.resetToDefault()
                        acoustIDApiKey = await AcoustIDConfiguration.shared.apiKey
                        acoustIDTestStatus = nil
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Restore to system built-in verified Application Key")
            }

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://acoustid.org/new-application")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Visit AcoustID to register and get your own Key")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }

                Text("·")
                    .foregroundStyle(.secondary)

                Text("Default built-in Key: cSpUJKpD")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
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

                    Text("Priority \(priorityIndex)")
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
                    TextField("Search fingerprints, songs, or artists…", text: $fingerprintSearchText)
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

                if !fingerprintRecords.isEmpty {
                    Button("Clean orphaned fingerprints") {
                        Task {
                            let cleaned = await LocalFingerprintRegistry.shared.cleanOrphanRecords(activeTracks: localStore.tracks)
                            await loadFingerprintRecords()
                            orphanCleanFeedback = cleaned > 0 ? "Cleaned \(cleaned) orphaned fingerprints" : "No orphaned fingerprints"
                            try? await Task.sleep(for: .seconds(3))
                            orphanCleanFeedback = nil
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Button("Clear all fingerprints") {
                        Task {
                            await LocalFingerprintRegistry.shared.removeAll()
                            await loadFingerprintRecords()
                            orphanCleanFeedback = "All fingerprints cleared"
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
                    Label("No learned fingerprints", systemImage: "waveform.badge.magnifyingglass")
                } description: {
                    Text("After importing songs via Import & Review or tagging them in the inspector, their PCM acoustic fingerprints are saved locally for instant recognition on future imports.")
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
                    Text("Fingerprint: \(record.fingerprint.prefix(16))…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)

                    Text("Duration: \(durationString(record.duration))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Hits: \(record.matchCount) times")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)

                    Text("Learned: \(record.dateLearned.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                Task {
                    await LocalFingerprintRegistry.shared.remove(fingerprint: record.fingerprint)
                    await loadFingerprintRecords()
                }
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
                Text("Folder heuristic rules let the system automatically attribute artists based on directory patterns without online queries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    isAddRulePresented = true
                } label: {
                    Label("Add New Rule…", systemImage: "plus")
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
                    Label("No Folder Learning Rules", systemImage: "folder.badge.gearshape")
                } description: {
                    Text("When importing organized music folders, the system automatically learns path features, or you can add custom rules above.")
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
                    Text("Path: \"\(rule.pathPattern)\"")
                        .font(.headline.monospaced())

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Artist: \(rule.targetArtist)")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)

                    if let album = rule.targetAlbum, !album.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("Album: \(album)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("Matches: \(rule.matchCount) times")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    Text("Added: \(rule.dateAdded.formatted(date: .abbreviated, time: .omitted))")
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
                Text("MusicBrainz Online Catalog Service")
                    .font(.title2.bold())

                Text("Global authoritative music metadata and release database (https://musicbrainz.org)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                statusRow(title: "Connection Status", value: "Connected (HTTP Web Service 2.0)", icon: "checkmark.circle.fill", color: .green)
                statusRow(title: "Rate Limiting", value: "Built-in 1.0s/req safety throttle", icon: "gauge.with.needle.fill", color: .blue)
                statusRow(title: "Cache Strategy", value: "Cached locally after first online lookup", icon: "bolt.shield.fill", color: .orange)
                statusRow(title: "Cover Art Source", value: "Cover Art Archive official archive", icon: "photo.stack.fill", color: .purple)
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

            Text(LocalizedStringKey(title))
                .font(.subheadline.bold())
                .frame(width: 140, alignment: .leading)

            Text(LocalizedStringKey(value))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Add Rule Sheet

    private var addRuleSheet: some View {
        VStack(spacing: 20) {
            Text("Add Folder Learning Rule")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path keyword (e.g. Pop/Artist)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Path pattern", text: $newRulePath)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Artist Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Artist Name", text: $newRuleArtist)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(width: 320)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isAddRulePresented = false
                }
                .buttonStyle(.bordered)

                Button("Save Rule") {
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
