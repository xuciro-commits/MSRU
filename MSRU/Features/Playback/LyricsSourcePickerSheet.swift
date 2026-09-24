//
//  LyricsSourcePickerSheet.swift
//  MSRU
//
//  Modal candidate switcher allowing users to search and select alternative lyrics versions.
//

import SwiftUI
import AppFoundation
import MusicDomain
import MusicPlayback
import MusicLibrary

struct LyricsSourcePickerSheet: View {
    let playback: PlaybackController
    @Environment(\.dismiss) private var dismiss

    @State private var lyricsStore = LyricsStore.shared
    @State private var searchQuery: String = ""
    @State private var candidates: [LrcLibResponse] = []
    @State private var isLoading: Bool = false
    @State private var hasSearched: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            searchBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            Divider()

            contentArea
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 480, idealHeight: 560)
        .background(.regularMaterial)
        .onAppear {
            let initial = playback.unifiedTitle
            searchQuery = initial
            performSearch(query: initial)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Search & Switch Lyrics")
                    .font(.headline)
                Text("Select an alternative lyric version or search by title/artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Song title or artist…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch(query: searchQuery)
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button("Search") {
                performSearch(query: searchQuery)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.regular)
                Text("Searching lyrics database…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if candidates.isEmpty && hasSearched {
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No lyrics found")
                    .font(.headline)
                Text("Try searching with the song title only, or switch between Simplified/Traditional Chinese.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(candidates, id: \.id) { candidate in
                        candidateRow(candidate)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Candidate Row

    @ViewBuilder
    private func candidateRow(_ candidate: LrcLibResponse) -> some View {
        let isSynced = candidate.syncedLyrics != nil && !(candidate.syncedLyrics?.isEmpty ?? true)
        let candidateDur = candidate.duration ?? 0
        let targetDur = playback.duration

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(candidate.trackName ?? "Unknown Title")
                            .font(.system(size: 14, weight: .semibold))

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(candidate.artistName ?? "Unknown Artist")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let album = candidate.albumName, !album.isEmpty {
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Button("Use") {
                    applyCandidate(candidate)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Metadata badges row
            HStack(spacing: 8) {
                if candidateDur > 0 {
                    let min = Int(candidateDur) / 60
                    let sec = Int(candidateDur) % 60
                    let timeStr = String(format: "%d:%02d", min, sec)

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(timeStr)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)

                    if targetDur > 0 {
                        let diff = abs(candidateDur - targetDur)
                        let diffText = String(format: "±%.0fs", diff)
                        Text(diffText)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                diff <= 15
                                    ? Color.green.opacity(0.15)
                                    : Color.secondary.opacity(0.08),
                                in: Capsule()
                            )
                            .foregroundStyle(diff <= 15 ? Color.green : Color.secondary)
                    }
                }

                if isSynced {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                        Text("Synced")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
                } else {
                    Text("Plain")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            // Preview snippet
            let previewText = snippet(from: isSynced ? candidate.syncedLyrics : candidate.plainLyrics)
            if !previewText.isEmpty {
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func performSearch(query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        searchTask?.cancel()
        isLoading = true
        hasSearched = true

        searchTask = Task {
            let results = await LyricsService.shared.searchCandidates(query: clean)
            if !Task.isCancelled {
                // Sort results: synced candidates first, then closest duration
                let target = playback.duration
                self.candidates = results.sorted { a, b in
                    let aSynced = a.syncedLyrics != nil && !(a.syncedLyrics?.isEmpty ?? true)
                    let bSynced = b.syncedLyrics != nil && !(b.syncedLyrics?.isEmpty ?? true)
                    if aSynced != bSynced {
                        return aSynced && !bSynced
                    }
                    if target > 0 {
                        let diffA = abs((a.duration ?? 0) - target)
                        let diffB = abs((b.duration ?? 0) - target)
                        return diffA < diffB
                    }
                    return false
                }
                self.isLoading = false
            }
        }
    }

    private func applyCandidate(_ candidate: LrcLibResponse) {
        Task {
            await lyricsStore.applyCandidate(candidate, playback: playback)
            dismiss()
        }
    }

    private func snippet(from raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let lines = raw.components(separatedBy: .newlines)
            .map { line -> String in
                // Strip timestamps e.g. [00:12.34]
                if let idx = line.lastIndex(of: "]") {
                    let after = line[line.index(after: idx)...]
                    return String(after).trimmingCharacters(in: .whitespaces)
                }
                return line.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }

        return lines.prefix(3).joined(separator: " / ")
    }
}

#Preview("Lyrics Source Picker Sheet") {
    let playback = MSRUPreviewData.makePlaybackController()
    LyricsSourcePickerSheet(playback: playback)
}
