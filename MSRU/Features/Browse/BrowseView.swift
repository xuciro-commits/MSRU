//
//  BrowseView.swift
//  MSRU
//
//  Apple Music-styled Browse (新发现 / 浏览) surface.
//  Features edge-to-edge continuous scrolling under sidebar/inspector panels with translucent chevrons.
//  Includes Artist Sharing (16:9), Apple Music Sessions, Club DJ Mixes, 3-Row New Tracks, and Genre Tiles.
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary

struct BrowseView: View {

    let feature: FeatureHost<BrowseFeature>

    @Bindable
    private var state: BrowseFeature.State

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 18)
    ]

    // MARK: - Init

    init(feature: FeatureHost<BrowseFeature>) {
        self.feature = feature
        self._state = Bindable(wrappedValue: feature.state)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                sourceSummary
                    .padding(.horizontal, 28)

                if let error = feature.libraryErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .padding(.horizontal, 28)
                }

                // 1. 探索流派与分类 (Explore by Genre Colorful Tiles)
                exploreGenreTilesSection
                    .padding(.horizontal, 28)

                // 2. Openverse 实时搜索结果
                openverseResultsSection
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 60)
        }
        .hideScrollIndicatorsCompletely()
        .task {
            feature.send(.appeared)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Browse"))
                    .font(.system(size: 34, weight: .bold))

                Text("Openly licensed music from Openverse.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Powered by Openverse", systemImage: "globe")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Provider Summary

    private var sourceSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe")
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("Openverse")
                    .font(.headline)

                Text("Openly licensed audio with its license details. Stream a track or save it to your library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

        }
        .padding(16)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - 1. 探索流派与分类 (Explore by Genre Colorful Tiles)

    private struct GenreTileItem: Identifiable {
        let id: String
        let name: LocalizedStringKey
        let query: String
        let gradient: LinearGradient
    }

    private let genreTiles: [GenreTileItem] = [
        GenreTileItem(
            id: "pop",
            name: "Pop",
            query: "Pop",
            gradient: LinearGradient(colors: [Color(red: 0.95, green: 0.35, blue: 0.55), Color(red: 0.7, green: 0.15, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "rock",
            name: "Rock",
            query: "Rock",
            gradient: LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.15), Color(red: 0.45, green: 0.1, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "jazz",
            name: "Jazz",
            query: "Jazz",
            gradient: LinearGradient(colors: [Color(red: 0.45, green: 0.25, blue: 0.65), Color(red: 0.85, green: 0.65, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "classical",
            name: "Classical",
            query: "Classical",
            gradient: LinearGradient(colors: [Color(red: 0.15, green: 0.35, blue: 0.65), Color(red: 0.05, green: 0.15, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "electronic",
            name: "Electronic",
            query: "Electronic",
            gradient: LinearGradient(colors: [Color(red: 0.15, green: 0.75, blue: 0.65), Color(red: 0.05, green: 0.35, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "soundtrack",
            name: "Soundtrack",
            query: "Soundtrack",
            gradient: LinearGradient(colors: [Color(red: 0.85, green: 0.55, blue: 0.2), Color(red: 0.5, green: 0.25, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "folk",
            name: "Folk",
            query: "Folk",
            gradient: LinearGradient(colors: [Color(red: 0.35, green: 0.65, blue: 0.35), Color(red: 0.15, green: 0.35, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "ambient",
            name: "Ambient",
            query: "Ambient",
            gradient: LinearGradient(colors: [Color(red: 0.4, green: 0.3, blue: 0.65), Color(red: 0.15, green: 0.4, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private var exploreGenreTilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Genres")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 14)], spacing: 14) {
                ForEach(genreTiles) { tile in
                    Button {
                        feature.send(.queryChanged(tile.query))
                        feature.send(.searchRequested(tile.query))
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(tile.gradient)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

                            Text(tile.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(14)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 6. Openverse 搜索结果

    @ViewBuilder
    private var openverseResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("From Openverse")
                    .font(.title2.bold())

                Spacer()

                if !state.results.isEmpty {
                    Text("\(state.results.count) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if state.isLoading && state.results.isEmpty {
                loadingState
            } else if let error = state.errorMessage, state.results.isEmpty {
                errorState(error)
            } else if state.results.isEmpty {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "music.note",
                    description: Text("Pick a genre above or search for something else.")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                    ForEach(state.results) { item in
                        audioCard(item)
                    }
                }
            }
        }
    }

    // MARK: - Loading & Error

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching Openverse…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorState(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Can't Reach Openverse", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") {
                feature.send(.retryRequested)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Audio Card

    private func audioCard(_ item: OpenverseAudio) -> some View {
        let isCurrent = feature.isCurrent(item)
        let isSaved = feature.isSaved(item)

        return VStack(alignment: .leading, spacing: 12) {
            artwork(item)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.creatorTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(item.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            metadata(item)

            HStack(spacing: 8) {
                Button {
                    feature.send(.playPauseRequested(item))
                } label: {
                    Label(
                        isCurrent && feature.isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"),
                        systemImage: isCurrent && feature.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)

                Spacer()

                if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .help("In Library")
                } else {
                    Button {
                        Task {
                            feature.send(.libraryToggleRequested(item))
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add to Library")
                }

                Menu {
                    actions(for: item)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 22)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(14)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? Color.primary.opacity(0.24) : Color.clear, lineWidth: 1)
        }
        .contextMenu {
            actions(for: item)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(for item: OpenverseAudio) -> some View {
        Button {
            feature.send(.playNextRequested(item))
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }

        Button {
            feature.send(.addToQueueRequested(item))
        } label: {
            Label("Add to Queue", systemImage: "text.badge.plus")
        }

        Divider()

        if feature.isSaved(item) {
            Button {
                feature.send(.libraryToggleRequested(item))
            } label: {
                Label("Remove from Library", systemImage: "minus.circle")
            }
        } else {
            Button {
                feature.send(.libraryToggleRequested(item))
            } label: {
                Label("Add to Library", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Metadata

    private func metadata(_ item: OpenverseAudio) -> some View {
        HStack(spacing: 6) {
            Text(item.sourceTitle)
                .lineLimit(1)

            Text("·")

            Text(item.licenseTitle)
                .lineLimit(1)

            if let duration = item.durationText {
                Text("·")
                Text(duration)
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    // MARK: - Artwork

    @ViewBuilder
    private func artwork(_ item: OpenverseAudio) -> some View {
        MediaImageView(
            url: item.thumbnailURL,
            thumbnailPixelSize: CGSize(width: 256, height: 256),
            cornerRadius: 12
        )
    }
}

// MARK: - Preview

#Preview("Browse") {
    @Previewable @State var showsContext = false
    let scene = MSRUPreviewData.makeScene(section: .browse)
    let session = MSRUApplicationShellSession(scene: scene)
    SwiftUIApplicationShell(shell: session.resolve(), isContextPresented: $showsContext) {
        SidebarPaneView(scene: scene)
    }
    .frame(width: 1100, height: 800)
}

#Preview("Browse · Content") {
    BrowseView(feature: MSRUPreviewData.makeBrowseFeature()).frame(width: 900, height: 700)
}
