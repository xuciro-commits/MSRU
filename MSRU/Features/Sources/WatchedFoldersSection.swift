//
//  WatchedFoldersSection.swift
//  MSRU
//
//  Folders MSRU watches for new music. Part of source management.
//

import SwiftUI
import MusicLibrary

struct WatchedFoldersSection: View {
    @Bindable var watchedFolders: WatchedFolderStore
    /// Opens the Sources page's folder picker, the single way folders are added.
    let onAddFolder: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Watched Folders"))
                            .font(.headline)
                        Text(LocalizedStringKey("MSRU automatically monitors these directories in the background. Any new or modified audio files will be incrementally ingested."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onAddFolder) {
                        Label(LocalizedStringKey("Add Folder"), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let msg = watchedFolders.statusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(LocalizedStringKey(msg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            if watchedFolders.folders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey("No Watched Folders Configured"))
                        .font(.headline)
                    Text(LocalizedStringKey("Click 'Add Folder' to select a local directory to watch."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            } else {
                ForEach(watchedFolders.folders) { folder in
                    watchedFolderCard(folder)
                }
            }

            HStack {
                if watchedFolders.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text(LocalizedStringKey("Scanning watched folders…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await watchedFolders.rescanAll()
                    }
                } label: {
                    Label(LocalizedStringKey("Rescan All"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(watchedFolders.isScanning)
            }
        }
    }

    private func watchedFolderCard(_ folder: WatchedFolder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(folder.isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(folder.displayName)
                            .font(.headline)

                        if folder.isEnabled {
                            if folder.isNetworkVolume {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 6, height: 6)
                                    Text(LocalizedStringKey("Network (Snapshot)"))
                                        .font(.caption2.bold())
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                            } else {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text(LocalizedStringKey("Monitoring"))
                                        .font(.caption2.bold())
                                        .foregroundStyle(.green)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12), in: Capsule())
                            }
                        } else {
                            Text(LocalizedStringKey("Paused"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 12) {
                        Text("\(folder.trackCount) " + String(localized: "tracks"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let lastScan = folder.lastScannedAt {
                            Text(String(localized: "Last scanned:") + " \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await watchedFolders.rescanFolder(id: folder.id)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Rescan this folder"))

                    Button {
                        openURL(folder.url)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Show in Finder"))

                    Button(role: .destructive) {
                        watchedFolders.removeFolder(id: folder.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Remove watched folder"))
                }
            }

            Divider()

            HStack {
                Toggle(LocalizedStringKey("Active Monitoring"), isOn: Binding(
                    get: { folder.isEnabled },
                    set: { _ in watchedFolders.toggleFolder(id: folder.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()

                Toggle(LocalizedStringKey("Auto-Ingest into Library"), isOn: Binding(
                    get: { folder.autoIngest },
                    set: { watchedFolders.setAutoIngest(id: folder.id, autoIngest: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

#Preview {
    WatchedFoldersSection(watchedFolders: MSRUPreviewData.makeApplication().watchedFolders, onAddFolder: {})
        .padding()
        .frame(width: 650)
}
